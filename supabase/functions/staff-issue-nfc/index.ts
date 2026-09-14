import '@supabase/functions-js/edge-runtime.d.ts';
import type { SupabaseClient } from '@supabase/supabase-js';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, parseJsonBody } from '../_shared/utils.ts';
import { getSupabaseAdminClient } from '../_shared/supabase.ts';
import { authenticateAndAuthorize } from '../_shared/auth.ts';
import type { IssueNfcRequest, IssueNfcResponse } from '../_shared/types.ts';

export async function handleStaffIssueNfc(
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

    // 2. Parse and validate request body
    const body = await parseJsonBody<IssueNfcRequest>(req);
    if (!body || typeof body.integranteId !== 'string' || body.integranteId.trim() === '') {
      return errorResponse(
        'El campo integranteId es requerido y debe ser una cadena no vacía',
        400
      );
    }

    const integranteId = body.integranteId.trim();

    // 3. Verify member exists in integrantes table
    const { data: integranteRaw, error: integranteError } = await supabaseAdmin
      .from('integrantes')
      .select('id, nfc_token, nfc_activa')
      .eq('id', integranteId)
      .maybeSingle();

    if (integranteError) {
      return errorResponse(
        'Error al verificar el integrante',
        500,
        integranteError.message
      );
    }

    if (!integranteRaw) {
      return errorResponse('Integrante no encontrado', 404);
    }

    // 4. Reactivate existing token or generate a fresh UUID
    const nfcToken: string =
      typeof integranteRaw.nfc_token === 'string' && integranteRaw.nfc_token.trim() !== ''
        ? integranteRaw.nfc_token.trim()
        : crypto.randomUUID();

    const now = new Date().toISOString();

    // 5. Update integrante: nfc_token, nfc_activa = true, nfc_emitida_en = now
    const { error: updateError } = await supabaseAdmin
      .from('integrantes')
      .update({
        nfc_token: nfcToken,
        nfc_activa: true,
        nfc_emitida_en: now,
      })
      .eq('id', integranteId);

    if (updateError) {
      return errorResponse(
        'Error al emitir/reactivar la tarjeta NFC',
        500,
        updateError.message
      );
    }

    // 6. Build response payload (strictly `staffapp:nfc:<nfcToken>`) without any personal data
    const payload = `staffapp:nfc:${nfcToken}`;

    const responseData: IssueNfcResponse = {
      integranteId,
      nfcToken,
      payload,
    };

    return jsonResponse(responseData, 200);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Error interno del servidor';
    return errorResponse(message, 500);
  }
}

if (typeof Deno !== 'undefined' && 'serve' in Deno) {
  Deno.serve((req: Request) => handleStaffIssueNfc(req));
}
