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
import type { SitecIssueNfcRequest, SitecIssueNfcResponse } from '../_shared/types.ts';

/**
 * Emite la tarjeta NFC de un asistente de SITEC en dos pasos:
 *
 * 1. Sin `written`, prepara la tarjeta: reactiva el token y devuelve el payload
 *    que la app escribe, igual que staff-issue-nfc.
 * 2. Con `written: true`, la app confirma que la escribió y solo entonces se
 *    marca `nfc_emitida_en`, que es lo que el registro muestra como «tarjeta
 *    escrita». Marcarlo al preparar contaría tarjetas que nunca llegaron a
 *    escribirse (NFC apagado, escritura cancelada, tarjeta protegida…).
 */
export async function handleStaffSitecIssueNfc(
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

    // 1. Mismo control que los accesos de SITEC: sesión de staff o admin, alta
    //    en staff y una función operativa con permiso para validar accesos.
    //    Es más estricto que la emisión del hackathon porque la lista de
    //    staff-sitec-asistentes da los ids de todos los asistentes.
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
        `Tu función de staff (${staffRol ?? 'sin asignar'}) no tiene permiso para registrar asistentes de SITEC`,
        403
      );
    }

    // 2. Parse and validate request body
    const body = await parseJsonBody<SitecIssueNfcRequest>(req);
    if (!body || typeof body.asistenteId !== 'string' || body.asistenteId.trim() === '') {
      return errorResponse(
        'El campo asistenteId es requerido y debe ser una cadena no vacía',
        400
      );
    }

    const asistenteId = body.asistenteId.trim();
    const written = body.written === true;

    // 3. El asistente tiene que existir. `id` es uuid: con otro formato la
    // consulta falla con 22P02, y eso es un asistente que no existe, no un 500.
    const { data: asistenteRaw, error: asistenteError } = await supabaseAdmin
      .from('sitec_asistentes')
      .select('id, nfc_token, nfc_activa')
      .eq('id', asistenteId)
      .maybeSingle();

    if (asistenteError && asistenteError.code !== '22P02') {
      return errorResponse('Error al verificar el asistente', 500, asistenteError.message);
    }

    if (!asistenteRaw) {
      return errorResponse('Asistente no encontrado', 404);
    }

    // 4. Como en el hackathon, se reactiva el token que ya tiene (en SITEC se
    // genera al cargar al asistente) y solo se crea uno si faltara.
    const nfcToken: string =
      typeof asistenteRaw.nfc_token === 'string' && asistenteRaw.nfc_token.trim() !== ''
        ? asistenteRaw.nfc_token.trim()
        : crypto.randomUUID();

    const updates = written
      ? { nfc_emitida_en: new Date().toISOString() }
      : { nfc_token: nfcToken, nfc_activa: true };

    const { error: updateError } = await supabaseAdmin
      .from('sitec_asistentes')
      .update(updates)
      .eq('id', asistenteId);

    if (updateError) {
      return errorResponse(
        written
          ? 'Error al marcar la tarjeta como escrita'
          : 'Error al emitir/reactivar la tarjeta NFC',
        500,
        updateError.message
      );
    }

    // 5. El payload lleva solo el token, ningún dato personal.
    const responseData: SitecIssueNfcResponse = {
      asistenteId,
      nfcToken,
      payload: `staffapp:nfc:${nfcToken}`,
    };

    return jsonResponse(responseData, 200);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Error interno del servidor';
    return errorResponse(message, 500);
  }
}

if (typeof Deno !== 'undefined' && 'serve' in Deno) {
  Deno.serve((req: Request) => handleStaffSitecIssueNfc(req));
}
