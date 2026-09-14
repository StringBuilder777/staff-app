import type { SupabaseClient } from '@supabase/supabase-js';
import type { AuthValidationResult, UserProfile } from './types.ts';

/**
 * Validates the caller's JWT token from the Authorization header,
 * then checks that the user has role 'staff' or 'admin' in public.perfiles.
 */
export async function authenticateAndAuthorize(
  req: Request,
  supabaseAdmin: SupabaseClient
): Promise<AuthValidationResult> {
  const authHeader = req.headers.get('Authorization') ?? req.headers.get('authorization');
  if (!authHeader) {
    return {
      authorized: false,
      statusCode: 401,
      error: 'Cabecera Authorization no proporcionada',
    };
  }

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match || !match[1]) {
    return {
      authorized: false,
      statusCode: 401,
      error: 'Formato de token Bearer inválido',
    };
  }

  const token = match[1].trim();
  if (!token) {
    return {
      authorized: false,
      statusCode: 401,
      error: 'Token Bearer vacío',
    };
  }

  // Validate the JWT against Supabase Auth
  const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
  if (userError || !userData?.user) {
    return {
      authorized: false,
      statusCode: 401,
      error: 'Token de autenticación inválido o expirado',
    };
  }

  const userId = userData.user.id;

  // Retrieve user role from public.perfiles
  const { data: perfilData, error: perfilError } = await supabaseAdmin
    .from('perfiles')
    .select('id, rol')
    .eq('id', userId)
    .maybeSingle();

  if (perfilError) {
    return {
      authorized: false,
      statusCode: 403,
      error: `Error al consultar el perfil de usuario: ${perfilError.message}`,
    };
  }

  if (!perfilData) {
    return {
      authorized: false,
      statusCode: 403,
      error: 'Perfil de usuario no registrado en la base de datos',
    };
  }

  const perfil = perfilData as UserProfile;
  if (perfil.rol !== 'staff' && perfil.rol !== 'admin') {
    return {
      authorized: false,
      statusCode: 403,
      error: 'Acceso no autorizado: se requiere rol de staff o admin',
    };
  }

  return {
    authorized: true,
    userId,
    perfil,
  };
}

/**
 * Resolves staff.id corresponding to a perfil_id.
 * 1. Checks public.staff where perfil_id = perfilId.
 * 2. Checks public.staff where id = perfilId (for backwards compatibility).
 * 3. Safely auto-registers staff record if missing.
 */
export async function resolveStaffId(
  supabaseAdmin: SupabaseClient,
  perfilId: string
): Promise<string | null> {
  // 1. Lookup by perfil_id
  const { data: staffByPerfil, error: err1 } = await supabaseAdmin
    .from('staff')
    .select('id')
    .eq('perfil_id', perfilId)
    .maybeSingle();

  if (!err1 && staffByPerfil?.id) {
    return String(staffByPerfil.id);
  }

  // 2. Lookup by id
  const { data: staffById, error: err2 } = await supabaseAdmin
    .from('staff')
    .select('id')
    .eq('id', perfilId)
    .maybeSingle();

  if (!err2 && staffById?.id) {
    return String(staffById.id);
  }

  // 3. Auto-insert staff entry for authorized staff/admin
  const { data: insertedStaff, error: insertErr } = await supabaseAdmin
    .from('staff')
    .insert({ perfil_id: perfilId })
    .select('id')
    .maybeSingle();

  if (!insertErr && insertedStaff?.id) {
    return String(insertedStaff.id);
  }

  return null;
}
