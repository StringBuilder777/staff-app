import '@supabase/functions-js/edge-runtime.d.ts';
import type { SupabaseClient } from '@supabase/supabase-js';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, parseJsonBody } from '../_shared/utils.ts';
import { getSupabaseAdminClient } from '../_shared/supabase.ts';
import { authenticateAndAuthorize, resolveStaffId } from '../_shared/auth.ts';
import { sanitizeEquipo, sanitizeIntegrante } from '../_shared/sanitizers.ts';
import {
  isValidAccessType,
  type AccessType,
  type ScanNfcAcceptedResponse,
  type ScanNfcDuplicateResponse,
  type ScanNfcRequest,
} from '../_shared/types.ts';

interface AccessColumns {
  timeCol: 'checkin_en' | 'desayuno_en' | 'comida_en';
  staffCol: 'checkin_registrado_por' | 'desayuno_registrado_por' | 'comida_registrado_por';
}

const ACCESS_FIELD_MAP: Record<AccessType, AccessColumns> = {
  checkin: {
    timeCol: 'checkin_en',
    staffCol: 'checkin_registrado_por',
  },
  desayuno: {
    timeCol: 'desayuno_en',
    staffCol: 'desayuno_registrado_por',
  },
  comida: {
    timeCol: 'comida_en',
    staffCol: 'comida_registrado_por',
  },
};

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
    const staffId = await resolveStaffId(supabaseAdmin, authResult.perfil.id);
    if (!staffId) {
      return errorResponse(
        'No se pudo resolver el identificador de staff correspondiente a tu usuario',
        403
      );
    }

    // 3. Parse and validate request body
    const body = await parseJsonBody<ScanNfcRequest>(req);
    if (!body || typeof body.nfcToken !== 'string' || body.nfcToken.trim() === '') {
      return errorResponse('El campo nfcToken es requerido y debe ser una cadena no vacía', 400);
    }

    if (!isValidAccessType(body.accessType)) {
      return errorResponse(
        'El campo accessType es inválido. Valores permitidos: checkin, desayuno, comida',
        400
      );
    }

    // Support both raw UUID or prefixed format `staffapp:nfc:<token>`
    const rawToken = body.nfcToken.trim();
    const nfcToken = rawToken.startsWith('staffapp:nfc:')
      ? rawToken.slice('staffapp:nfc:'.length).trim()
      : rawToken;

    const accessType: AccessType = body.accessType;
    const { timeCol, staffCol } = ACCESS_FIELD_MAP[accessType];
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
