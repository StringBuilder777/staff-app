import '@supabase/functions-js/edge-runtime.d.ts';
import type { SupabaseClient } from '@supabase/supabase-js';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse } from '../_shared/utils.ts';
import { getSupabaseAdminClient } from '../_shared/supabase.ts';
import {
  authenticateAndAuthorize,
  canScanAccess,
  resolveStaffId,
} from '../_shared/auth.ts';
import { sanitizeSitecRegistroAsistente } from '../_shared/sanitizers.ts';
import type { SitecAsistentesResponse, SitecRegistroAsistente } from '../_shared/types.ts';

/**
 * Asistentes de SITEC para el registro, donde el staff busca a cada asistente
 * por nombre y escribe su tarjeta. Son del orden de cien, así que se devuelven
 * todos y la app filtra mientras se escribe.
 */
export async function handleStaffSitecAsistentes(
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
    //    Es más estricto que la emisión del hackathon porque aquí cualquier
    //    cuenta vería la lista entera, no solo el equipo cuyo QR tiene delante.
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

    // 2. Solo las columnas que usa el registro. El token NFC no sale de aquí.
    const { data, error } = await supabaseAdmin
      .from('sitec_asistentes')
      .select('id, nombre, apellidos, nfc_emitida_en');

    if (error) {
      return errorResponse('Error al consultar los asistentes de SITEC', 500, error.message);
    }

    // 3. Orden alfabético por el nombre tal como se muestra en la app.
    const asistentes = ((data ?? []) as Record<string, unknown>[])
      .map(sanitizeSitecRegistroAsistente)
      .sort((a, b) =>
        fullName(a).localeCompare(fullName(b), 'es', { sensitivity: 'base' })
      );

    const responseData: SitecAsistentesResponse = { asistentes };
    return jsonResponse(responseData, 200);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Error interno del servidor';
    return errorResponse(message, 500);
  }
}

function fullName(asistente: SitecRegistroAsistente): string {
  return `${asistente.nombre} ${asistente.apellidos ?? ''}`.trim();
}

if (typeof Deno !== 'undefined' && 'serve' in Deno) {
  Deno.serve((req: Request) => handleStaffSitecAsistentes(req));
}
