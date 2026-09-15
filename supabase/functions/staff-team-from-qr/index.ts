import '@supabase/functions-js/edge-runtime.d.ts';
import type { SupabaseClient } from '@supabase/supabase-js';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, parseJsonBody } from '../_shared/utils.ts';
import { getSupabaseAdminClient } from '../_shared/supabase.ts';
import { authenticateAndAuthorize } from '../_shared/auth.ts';
import { sanitizeEquipo, sanitizeIntegrante } from '../_shared/sanitizers.ts';
import type { TeamFromQrRequest, TeamFromQrResponse } from '../_shared/types.ts';

export async function handleStaffTeamFromQr(
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
    const body = await parseJsonBody<TeamFromQrRequest>(req);
    if (!body || typeof body.qrToken !== 'string' || body.qrToken.trim() === '') {
      return errorResponse('El campo qrToken es requerido y debe ser una cadena no vacía', 400);
    }

    const qrToken = body.qrToken.trim();

    // 3. Search team by equipos.qr_token or id, extracting UUID from URLs if applicable
    const uuidMatch = qrToken.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
    const candidateTokens: string[] = [];
    if (uuidMatch) candidateTokens.push(uuidMatch[0].toLowerCase());
    if (!candidateTokens.includes(qrToken)) candidateTokens.push(qrToken);

    let equipoRaw: Record<string, unknown> | null = null;

    for (const tokenToTry of candidateTokens) {
      // Try by qr_token
      const { data: byQr, error: errQr } = await supabaseAdmin
        .from('equipos')
        .select('*')
        .eq('qr_token', tokenToTry)
        .maybeSingle();

      if (!errQr && byQr) {
        equipoRaw = byQr as Record<string, unknown>;
        break;
      }

      // If Postgres error is other than invalid UUID syntax (22P02), return 500
      if (errQr && errQr.code !== '22P02') {
        return errorResponse('Error al consultar el equipo', 500, errQr.message);
      }

      // Try by id if candidate is a UUID
      if (uuidMatch) {
        const { data: byId, error: errId } = await supabaseAdmin
          .from('equipos')
          .select('*')
          .eq('id', tokenToTry)
          .maybeSingle();

        if (!errId && byId) {
          equipoRaw = byId as Record<string, unknown>;
          break;
        }
      }
    }

    if (!equipoRaw) {
      return errorResponse('Equipo no encontrado para el código QR proporcionado', 404);
    }

    // 4. Retrieve team members (integrantes)
    const { data: integrantesRaw, error: integrantesError } = await supabaseAdmin
      .from('integrantes')
      .select('*')
      .eq('equipo_id', equipoRaw.id);

    if (integrantesError) {
      return errorResponse(
        'Error al consultar los integrantes del equipo',
        500,
        integrantesError.message
      );
    }

    // 5. Sanitize and strictly strip sensitive fields (allergies, phones, emergency contacts, emails)
    const equipo = sanitizeEquipo(equipoRaw as Record<string, unknown>);
    const rawList = (integrantesRaw ?? []) as Array<Record<string, unknown>>;
    const integrantes = rawList.map((row: Record<string, unknown>) => sanitizeIntegrante(row));

    const responseData: TeamFromQrResponse = {
      equipo,
      integrantes,
    };

    return jsonResponse(responseData, 200);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Error interno del servidor';
    return errorResponse(message, 500);
  }
}

if (typeof Deno !== 'undefined' && 'serve' in Deno) {
  Deno.serve((req: Request) => handleStaffTeamFromQr(req));
}
