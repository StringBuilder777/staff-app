import '@supabase/functions-js/edge-runtime.d.ts';
import type { SupabaseClient } from '@supabase/supabase-js';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, parseJsonBody } from '../_shared/utils.ts';
import { getSupabaseAdminClient } from '../_shared/supabase.ts';
import {
  authenticateAndAuthorize,
  canScanAccess,
  resolveStaffId,
} from '../_shared/auth.ts';
import { sanitizeEquipo, sanitizeIntegrante } from '../_shared/sanitizers.ts';
import {
  isValidScanAccessType,
  SALIDA_ACCESS_TYPE,
  VALID_SCAN_ACCESS_TYPES,
  type AccessType,
  type OperationalEquipo,
  type SalidaMovimiento,
  type ScanNfcAcceptedResponse,
  type ScanNfcDuplicateResponse,
  type ScanNfcRequest,
  type ScanNfcSalidaAcceptedResponse,
  type ScanNfcSalidaDuplicateResponse,
} from '../_shared/types.ts';

interface AccessColumns {
  timeCol: 'checkin_en' | 'cena_en' | 'desayuno_en' | 'comida_en' | 'checkout_en';
  staffCol:
    | 'checkin_registrado_por'
    | 'cena_registrado_por'
    | 'desayuno_registrado_por'
    | 'comida_registrado_por'
    | 'checkout_registrado_por';
}

const ACCESS_FIELD_MAP: Record<AccessType, AccessColumns> = {
  checkin: {
    timeCol: 'checkin_en',
    staffCol: 'checkin_registrado_por',
  },
  cena: {
    timeCol: 'cena_en',
    staffCol: 'cena_registrado_por',
  },
  desayuno: {
    timeCol: 'desayuno_en',
    staffCol: 'desayuno_registrado_por',
  },
  comida: {
    timeCol: 'comida_en',
    staffCol: 'comida_registrado_por',
  },
  checkout: {
    timeCol: 'checkout_en',
    staffCol: 'checkout_registrado_por',
  },
};

/**
 * Dos lecturas de la misma tarjeta en la salida con menos de esto entre ellas
 * son una doble lectura (la tarjeta se quedó junto al teléfono, se tocó dos
 * veces el aviso...) y no un regreso de verdad: la segunda no cambia nada. Un
 * reintento tras perder la respuesta se reconoce aparte, por su lecturaId.
 */
export const SALIDA_DOBLE_LECTURA_MS = 30_000;

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const SALIDA_COLUMNS = 'id, salio_en, regreso_en, salida_lectura_id, regreso_lectura_id';

interface SalidaRow {
  id: string;
  salio_en: string;
  regreso_en: string | null;
  salida_lectura_id: string | null;
  regreso_lectura_id: string | null;
}

function salidaAceptada(
  movimiento: SalidaMovimiento,
  registeredAt: string,
  salioEn: string,
  integranteRaw: Record<string, unknown>,
  equipo: OperationalEquipo | null,
  repetida = false
): Response {
  const acceptedResponse: ScanNfcSalidaAcceptedResponse = {
    status: 'accepted',
    accessType: SALIDA_ACCESS_TYPE,
    movimiento,
    registeredAt,
    salioEn,
    ...(repetida ? { repetida: true } : {}),
    participante: sanitizeIntegrante(integranteRaw),
    equipo,
  };
  return jsonResponse(acceptedResponse, 200);
}

function salidaDuplicada(
  movimiento: SalidaMovimiento,
  previouslyRegisteredAt: string,
  error: string,
  integranteRaw: Record<string, unknown>,
  equipo: OperationalEquipo | null
): Response {
  const duplicateResponse: ScanNfcSalidaDuplicateResponse = {
    status: 'duplicate',
    error,
    accessType: SALIDA_ACCESS_TYPE,
    movimiento,
    previouslyRegisteredAt,
    participante: sanitizeIntegrante(integranteRaw),
    equipo,
  };
  return jsonResponse(duplicateResponse, 409);
}

/**
 * Lo que ya registró esta misma lectura, si la app la reintenta porque no le
 * llegó la respuesta. null si la lectura es nueva.
 */
async function lecturaPrevia(
  supabaseAdmin: SupabaseClient,
  integranteId: string,
  lecturaId: string,
  integranteRaw: Record<string, unknown>,
  equipo: OperationalEquipo | null
): Promise<Response | null> {
  const { data: abiertaRaw, error: abiertaError } = await supabaseAdmin
    .from('hackathon_salidas')
    .select(SALIDA_COLUMNS)
    .eq('integrante_id', integranteId)
    .eq('salida_lectura_id', lecturaId)
    .maybeSingle();
  if (abiertaError) {
    return errorResponse(
      'Error al consultar las salidas del participante',
      500,
      abiertaError.message
    );
  }
  const abierta = abiertaRaw as unknown as SalidaRow | null;
  if (abierta) {
    return salidaAceptada('salida', abierta.salio_en, abierta.salio_en, integranteRaw, equipo, true);
  }

  const { data: cerradaRaw, error: cerradaError } = await supabaseAdmin
    .from('hackathon_salidas')
    .select(SALIDA_COLUMNS)
    .eq('integrante_id', integranteId)
    .eq('regreso_lectura_id', lecturaId)
    .maybeSingle();
  if (cerradaError) {
    return errorResponse(
      'Error al consultar las salidas del participante',
      500,
      cerradaError.message
    );
  }
  const cerrada = cerradaRaw as unknown as SalidaRow | null;
  if (cerrada?.regreso_en) {
    return salidaAceptada('regreso', cerrada.regreso_en, cerrada.salio_en, integranteRaw, equipo, true);
  }

  return null;
}

/**
 * Punto «Salida»: si la persona está dentro, abre una salida; si está fuera,
 * la cierra con su regreso. Quien está fuera es quien tiene una fila sin
 * regreso_en en hackathon_salidas, y el índice hackathon_salidas_una_abierta_idx
 * no deja tener dos, así que dos teléfonos que leen a la vez no la duplican.
 *
 * Con lecturaId, la lectura es idempotente: un reintento de la misma lectura
 * devuelve lo que ya registró y no vuelve a alternar.
 */
async function registrarSalida(
  supabaseAdmin: SupabaseClient,
  integranteRaw: Record<string, unknown>,
  equipo: OperationalEquipo | null,
  staffId: string,
  lecturaId: string | null
): Promise<Response> {
  const integranteId = String(integranteRaw.id);
  const nowMs = Date.now();
  const now = new Date(nowMs).toISOString();

  // Cuenta como última lectura de la tarjeta, cambie algo o no.
  await supabaseAdmin
    .from('integrantes')
    .update({ nfc_ultimo_leido_en: now })
    .eq('id', integranteId);

  // 1. Un reintento de una lectura que ya se registró devuelve lo mismo.
  if (lecturaId) {
    const previa = await lecturaPrevia(supabaseAdmin, integranteId, lecturaId, integranteRaw, equipo);
    if (previa) return previa;
  }

  // 2. Su salida abierta, si la tiene. Solo puede haber una.
  const { data: abiertaRaw, error: abiertaError } = await supabaseAdmin
    .from('hackathon_salidas')
    .select(SALIDA_COLUMNS)
    .eq('integrante_id', integranteId)
    .is('regreso_en', null)
    .maybeSingle();

  if (abiertaError) {
    return errorResponse(
      'Error al consultar las salidas del participante',
      500,
      abiertaError.message
    );
  }

  const abierta = abiertaRaw as unknown as SalidaRow | null;

  if (abierta) {
    // Doble lectura: la salida se acaba de registrar.
    if (nowMs - Date.parse(abierta.salio_en) < SALIDA_DOBLE_LECTURA_MS) {
      return salidaDuplicada(
        'salida',
        abierta.salio_en,
        'La salida de este participante se acaba de registrar',
        integranteRaw,
        equipo
      );
    }

    // Estaba fuera: esta lectura es su regreso. Solo cierra la salida si
    // sigue abierta al ejecutarse.
    const { data: cerradas, error: cerrarError } = await supabaseAdmin
      .from('hackathon_salidas')
      .update({ regreso_en: now, regreso_registrado_por: staffId, regreso_lectura_id: lecturaId })
      .eq('id', abierta.id)
      .is('regreso_en', null)
      .select(SALIDA_COLUMNS);

    if (cerrarError) {
      // 23505: esta misma lectura ya cerró la salida en una petición paralela.
      if (cerrarError.code === '23505' && lecturaId) {
        const previa = await lecturaPrevia(supabaseAdmin, integranteId, lecturaId, integranteRaw, equipo);
        if (previa) return previa;
      }
      return errorResponse(
        'Error al registrar el regreso del participante',
        500,
        cerrarError.message
      );
    }

    // Sin filas: otro dispositivo (o esta misma lectura, reintentada en
    // paralelo) registró el regreso entre la consulta y el UPDATE.
    if (!cerradas || cerradas.length === 0) {
      const { data: refreshedRaw } = await supabaseAdmin
        .from('hackathon_salidas')
        .select(SALIDA_COLUMNS)
        .eq('id', abierta.id)
        .maybeSingle();
      const refreshed = refreshedRaw as unknown as SalidaRow | null;
      if (lecturaId && refreshed?.regreso_en && refreshed.regreso_lectura_id === lecturaId) {
        return salidaAceptada('regreso', refreshed.regreso_en, refreshed.salio_en, integranteRaw, equipo, true);
      }
      return salidaDuplicada(
        'regreso',
        refreshed?.regreso_en ?? now,
        'El regreso de este participante fue registrado concurrentemente por otro dispositivo',
        integranteRaw,
        equipo
      );
    }

    return salidaAceptada('regreso', now, abierta.salio_en, integranteRaw, equipo);
  }

  // 3. Está dentro. Si su regreso se registró hace unos segundos, es una
  //    doble lectura y no una salida nueva.
  const { data: ultimasRaw, error: ultimaError } = await supabaseAdmin
    .from('hackathon_salidas')
    .select(SALIDA_COLUMNS)
    .eq('integrante_id', integranteId)
    .order('regreso_en', { ascending: false, nullsFirst: false })
    .limit(1);

  if (ultimaError) {
    return errorResponse(
      'Error al consultar las salidas del participante',
      500,
      ultimaError.message
    );
  }

  const ultima = ((ultimasRaw ?? [])[0] ?? null) as unknown as SalidaRow | null;
  if (ultima?.regreso_en && nowMs - Date.parse(ultima.regreso_en) < SALIDA_DOBLE_LECTURA_MS) {
    return salidaDuplicada(
      'regreso',
      ultima.regreso_en,
      'El regreso de este participante se acaba de registrar',
      integranteRaw,
      equipo
    );
  }

  // 4. Abre una salida.
  const { error: abrirError } = await supabaseAdmin
    .from('hackathon_salidas')
    .insert({
      integrante_id: integranteId,
      salio_en: now,
      salida_registrado_por: staffId,
      salida_lectura_id: lecturaId,
    })
    .select(SALIDA_COLUMNS);

  if (abrirError) {
    // 23505: esta misma lectura la abrió una petición paralela, u otro
    // dispositivo abrió su salida entre la consulta y el INSERT.
    if (abrirError.code === '23505') {
      if (lecturaId) {
        const previa = await lecturaPrevia(supabaseAdmin, integranteId, lecturaId, integranteRaw, equipo);
        if (previa) return previa;
      }
      const { data: otraRaw } = await supabaseAdmin
        .from('hackathon_salidas')
        .select(SALIDA_COLUMNS)
        .eq('integrante_id', integranteId)
        .is('regreso_en', null)
        .maybeSingle();
      return salidaDuplicada(
        'salida',
        (otraRaw as unknown as SalidaRow | null)?.salio_en ?? now,
        'La salida de este participante fue registrada concurrentemente por otro dispositivo',
        integranteRaw,
        equipo
      );
    }

    return errorResponse(
      'Error al registrar la salida del participante',
      500,
      abrirError.message
    );
  }

  return salidaAceptada('salida', now, now, integranteRaw, equipo);
}

export async function handleStaffScanNfc(
  req: Request,
  customClient?: SupabaseClient
): Promise<Response> {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return errorResponse('Método no permitido. Utilice POST.', 405);
  }

  try {
    const supabaseAdmin = customClient ?? getSupabaseAdminClient();

    // 1. Authenticate JWT and authorize staff/admin role
    const authResult = await authenticateAndAuthorize(req, supabaseAdmin);
    if (!authResult.authorized) {
      return errorResponse(authResult.error, authResult.statusCode);
    }

    // 2. Resolve staff.id by staff.perfil_id
    const {
      staffId,
      rol: staffRol,
      error: staffError,
    } = await resolveStaffId(supabaseAdmin, authResult.perfil.id);
    if (!staffId) {
      return errorResponse(
        staffError ??
          'No se pudo resolver el identificador de staff correspondiente a tu usuario',
        403
      );
    }

    // No toda función operativa valida accesos: Mentor, Jurado y Comunicación
    // no operan los filtros. El permiso se consulta en el catálogo.
    const permiso = await canScanAccess(supabaseAdmin, staffRol ?? '');
    if (permiso.error) {
      return errorResponse(permiso.error, 500);
    }
    if (!permiso.allowed) {
      return errorResponse(
        `Tu función de staff (${staffRol ?? 'sin asignar'}) no tiene permiso para validar accesos`,
        403
      );
    }

    // 3. Parse and validate request body
    const body = await parseJsonBody<ScanNfcRequest>(req);
    if (!body || typeof body.nfcToken !== 'string' || body.nfcToken.trim() === '') {
      return errorResponse('El campo nfcToken es requerido y debe ser una cadena no vacía', 400);
    }

    if (!isValidScanAccessType(body.accessType)) {
      return errorResponse(
        `El campo accessType es inválido. Valores permitidos: ${VALID_SCAN_ACCESS_TYPES.join(', ')}`,
        400
      );
    }

    // Support both raw UUID or prefixed format `staffapp:nfc:<token>`
    const rawToken = body.nfcToken.trim();
    const nfcToken = rawToken.startsWith('staffapp:nfc:')
      ? rawToken.slice('staffapp:nfc:'.length).trim()
      : rawToken;

    const accessType = body.accessType;
    const now = new Date().toISOString();

    // 4. Find member with valid nfc_token and nfc_activa = true
    const { data: integranteRaw, error: integranteError } = await supabaseAdmin
      .from('integrantes')
      .select('*')
      .eq('nfc_token', nfcToken)
      .eq('nfc_activa', true)
      .maybeSingle();

    if (integranteError) {
      return errorResponse(
        'Error al consultar el participante por NFC',
        500,
        integranteError.message
      );
    }

    if (!integranteRaw) {
      return errorResponse('Tarjeta NFC no encontrada o inactiva', 404);
    }

    // 5. Retrieve associated team if equipo_id is present
    let equipoRaw: Record<string, unknown> | null = null;
    if (integranteRaw.equipo_id) {
      const { data: teamData } = await supabaseAdmin
        .from('equipos')
        .select('*')
        .eq('id', integranteRaw.equipo_id)
        .maybeSingle();

      if (teamData) {
        equipoRaw = teamData as Record<string, unknown>;
      }
    }

    const equipo = equipoRaw ? sanitizeEquipo(equipoRaw) : null;

    // La salida es un interruptor y no un punto de una sola vez: va aparte.
    if (accessType === SALIDA_ACCESS_TYPE) {
      // Un lecturaId que no sea uuid no se puede guardar: se ignora y la
      // lectura funciona como siempre, sin reconocer reintentos.
      const lecturaId =
        typeof body.lecturaId === 'string' && UUID_PATTERN.test(body.lecturaId.trim())
          ? body.lecturaId.trim().toLowerCase()
          : null;
      return await registrarSalida(
        supabaseAdmin,
        integranteRaw as Record<string, unknown>,
        equipo,
        staffId,
        lecturaId
      );
    }

    const { timeCol, staffCol } = ACCESS_FIELD_MAP[accessType];

    // 6. Check if access was already recorded for this event
    const existingTimestamp = integranteRaw[timeCol];
    if (typeof existingTimestamp === 'string' && existingTimestamp.trim() !== '') {
      // Update nfc_ultimo_leido_en even on duplicate scan
      await supabaseAdmin
        .from('integrantes')
        .update({ nfc_ultimo_leido_en: now })
        .eq('id', integranteRaw.id);

      const duplicateResponse: ScanNfcDuplicateResponse = {
        status: 'duplicate',
        error: `El acceso de ${accessType} ya había sido registrado para este participante`,
        accessType,
        previouslyRegisteredAt: existingTimestamp,
        participante: sanitizeIntegrante(integranteRaw as Record<string, unknown>),
        equipo,
      };

      return jsonResponse(duplicateResponse, 409);
    }

    // 7. Atomic update: only updates if timeCol IS NULL at execution time
    const { data: updatedRows, error: updateError } = await supabaseAdmin
      .from('integrantes')
      .update({
        [timeCol]: now,
        [staffCol]: staffId,
        nfc_ultimo_leido_en: now,
      })
      .eq('id', integranteRaw.id)
      .is(timeCol, null)
      .select('*');

    if (updateError) {
      return errorResponse(
        'Error al registrar el acceso del participante',
        500,
        updateError.message
      );
    }

    // If 0 rows were updated, a concurrent scan already registered this access
    if (!updatedRows || updatedRows.length === 0) {
      const { data: refreshed } = await supabaseAdmin
        .from('integrantes')
        .select('*')
        .eq('id', integranteRaw.id)
        .single();

      const conflictingRow = (refreshed ?? integranteRaw) as Record<string, unknown>;
      const conflictingTimestamp =
        typeof conflictingRow[timeCol] === 'string'
          ? (conflictingRow[timeCol] as string)
          : now;

      const duplicateResponse: ScanNfcDuplicateResponse = {
        status: 'duplicate',
        error: `El acceso de ${accessType} fue registrado concurrentemente por otro dispositivo`,
        accessType,
        previouslyRegisteredAt: conflictingTimestamp,
        participante: sanitizeIntegrante(conflictingRow),
        equipo,
      };

      return jsonResponse(duplicateResponse, 409);
    }

    // 8. Successful registration: return operational data
    const acceptedResponse: ScanNfcAcceptedResponse = {
      status: 'accepted',
      accessType,
      registeredAt: now,
      participante: sanitizeIntegrante(updatedRows[0] as Record<string, unknown>),
      equipo,
    };

    return jsonResponse(acceptedResponse, 200);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Error interno del servidor';
    return errorResponse(message, 500);
  }
}

if (typeof Deno !== 'undefined' && 'serve' in Deno) {
  Deno.serve((req: Request) => handleStaffScanNfc(req));
}
