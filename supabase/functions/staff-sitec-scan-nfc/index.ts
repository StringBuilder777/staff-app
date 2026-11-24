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
import { sanitizeSitecAsistente } from '../_shared/sanitizers.ts';
import {
  VALID_SITEC_ACCESS_TYPES,
  isValidSitecAccessType,
  type SitecAccessType,
  type SitecScanNfcAcceptedResponse,
  type SitecScanNfcDuplicateResponse,
  type SitecScanNfcRequest,
} from '../_shared/types.ts';

// nfc_token es uuid en la tabla. Un texto que no lo sea no puede ser una
// credencial de SITEC, y mandarlo a la consulta haría fallar a Postgres con un
// 500 en vez del 404 que corresponde a una tarjeta ajena.
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const NOT_FOUND_MESSAGE = 'Tarjeta NFC no registrada en SITEC o inactiva';

/**
 * Valida un punto de acceso de SITEC (entrada, comida o salida del jueves o
 * del viernes) leyendo la tarjeta NFC del asistente.
 *
 * Es la lógica de staff-scan-nfc aplicada a sitec_asistentes: SITEC no comparte
 * asistentes ni equipos con el hackathon, y así ninguna de las dos funciones
 * toca las tablas de la otra.
 */
export async function handleStaffSitecScanNfc(
  req: Request,
  customClient?: SupabaseClient
): Promise<Response> {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return errorResponse('Método no permitido. Utilice POST.', 405);
  }

  try {
    const supabaseAdmin = customClient ?? getSupabaseAdminClient();

    // 1. Mismo control que el hackathon: sesión de staff o admin, alta en staff
    //    y una función operativa con permiso para validar accesos.
    const authResult = await authenticateAndAuthorize(req, supabaseAdmin);
    if (!authResult.authorized) {
      return errorResponse(authResult.error, authResult.statusCode);
    }

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

    // 2. Cuerpo de la petición
    const body = await parseJsonBody<SitecScanNfcRequest>(req);
    if (!body || typeof body.nfcToken !== 'string' || body.nfcToken.trim() === '') {
      return errorResponse('El campo nfcToken es requerido y debe ser una cadena no vacía', 400);
    }

    if (!isValidSitecAccessType(body.accessType)) {
      return errorResponse(
        `El campo accessType es inválido. Valores permitidos: ${VALID_SITEC_ACCESS_TYPES.join(', ')}`,
        400
      );
    }

    // Las tarjetas usan el mismo formato que las del hackathon.
    const rawToken = body.nfcToken.trim();
    const nfcToken = rawToken.startsWith('staffapp:nfc:')
      ? rawToken.slice('staffapp:nfc:'.length).trim()
      : rawToken;

    if (!UUID_PATTERN.test(nfcToken)) {
      return errorResponse(NOT_FOUND_MESSAGE, 404);
    }

    const accessType: SitecAccessType = body.accessType;
    // Cada punto es un par de columnas con su mismo nombre. Solo se construyen
    // a partir de un accessType ya validado contra la lista cerrada.
    const timeCol = `${accessType}_en`;
    const staffCol = `${accessType}_registrado_por`;
    const now = new Date().toISOString();

    // 3. Asistente con esa tarjeta, y activa
    const { data: asistenteRaw, error: asistenteError } = await supabaseAdmin
      .from('sitec_asistentes')
      .select('*')
      .eq('nfc_token', nfcToken)
      .eq('nfc_activa', true)
      .maybeSingle();

    if (asistenteError) {
      return errorResponse(
        'Error al consultar el asistente por NFC',
        500,
        asistenteError.message
      );
    }

    if (!asistenteRaw) {
      return errorResponse(NOT_FOUND_MESSAGE, 404);
    }

    // 4. Punto ya registrado para este asistente
    const existingTimestamp = asistenteRaw[timeCol];
    if (typeof existingTimestamp === 'string' && existingTimestamp.trim() !== '') {
      // La última lectura se anota también en los duplicados.
      await supabaseAdmin
        .from('sitec_asistentes')
        .update({ nfc_ultimo_leido_en: now })
        .eq('id', asistenteRaw.id);

      const duplicateResponse: SitecScanNfcDuplicateResponse = {
        status: 'duplicate',
        error: `El acceso ${accessType} ya había sido registrado para este asistente`,
        accessType,
        previouslyRegisteredAt: existingTimestamp,
        asistente: sanitizeSitecAsistente(asistenteRaw as Record<string, unknown>),
      };

      return jsonResponse(duplicateResponse, 409);
    }

    // 5. Registro atómico: solo escribe si la columna sigue vacía al ejecutarse
    const { data: updatedRows, error: updateError } = await supabaseAdmin
      .from('sitec_asistentes')
      .update({
        [timeCol]: now,
        [staffCol]: staffId,
        nfc_ultimo_leido_en: now,
      })
      .eq('id', asistenteRaw.id)
      .is(timeCol, null)
      .select('*');

    if (updateError) {
      return errorResponse(
        'Error al registrar el acceso del asistente',
        500,
        updateError.message
      );
    }

    // Sin filas: otro dispositivo registró este punto entre la lectura y el UPDATE
    if (!updatedRows || updatedRows.length === 0) {
      const { data: refreshed } = await supabaseAdmin
        .from('sitec_asistentes')
        .select('*')
        .eq('id', asistenteRaw.id)
        .single();

      const conflictingRow = (refreshed ?? asistenteRaw) as Record<string, unknown>;
      const conflictingTimestamp =
        typeof conflictingRow[timeCol] === 'string'
          ? (conflictingRow[timeCol] as string)
          : now;

      const duplicateResponse: SitecScanNfcDuplicateResponse = {
        status: 'duplicate',
        error: `El acceso ${accessType} fue registrado concurrentemente por otro dispositivo`,
        accessType,
        previouslyRegisteredAt: conflictingTimestamp,
        asistente: sanitizeSitecAsistente(conflictingRow),
      };

      return jsonResponse(duplicateResponse, 409);
    }

    // 6. Acceso registrado
    const acceptedResponse: SitecScanNfcAcceptedResponse = {
      status: 'accepted',
      accessType,
      registeredAt: now,
      asistente: sanitizeSitecAsistente(updatedRows[0] as Record<string, unknown>),
    };

    return jsonResponse(acceptedResponse, 200);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Error interno del servidor';
    return errorResponse(message, 500);
  }
}

if (typeof Deno !== 'undefined' && 'serve' in Deno) {
  Deno.serve((req: Request) => handleStaffSitecScanNfc(req));
}
