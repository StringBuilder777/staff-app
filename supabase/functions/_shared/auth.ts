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
    const globalObj = globalThis as unknown as {
      process?: { env?: Record<string, string> };
      Deno?: { env?: { get: (k: string) => string | undefined } };
    };
    const allowAnonDev =
      (globalObj.Deno?.env?.get('DEV_ALLOW_ANON_STAFF') ??
        globalObj.process?.env?.['DEV_ALLOW_ANON_STAFF']) === 'true';
    if (allowAnonDev) {
      const { data: perfiles } = await supabaseAdmin
        .from('perfiles')
        .select('id, rol');

      const devPerfil = (perfiles as unknown as UserProfile[] | null)?.find(
        (p) => p.rol === 'staff' || p.rol === 'admin'
      );

      if (devPerfil) {
        return {
          authorized: true,
          userId: String(devPerfil.id),
          perfil: devPerfil as UserProfile,
        };
      }
    }

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

export interface StaffResolution {
  staffId: string | null;
  /** Función operativa del catálogo roles_staff, por ejemplo "Logística". */
  rol?: string;
  /** Motivo concreto del fallo, para no devolver un mensaje genérico al cliente. */
  error?: string;
}

export interface ScanPermission {
  allowed: boolean;
  /** Presente solo si la comprobación falló; distinto de no tener permiso. */
  error?: string;
}

/**
 * Indica si una función operativa puede validar accesos leyendo NFC.
 *
 * El permiso vive en roles_staff.puede_escanear, así que cambiar la política es
 * un UPDATE en la base y no exige volver a desplegar esta función.
 */
export async function canScanAccess(
  supabaseAdmin: SupabaseClient,
  rol: string
): Promise<ScanPermission> {
  if (!rol) return { allowed: false };

  const { data, error } = await supabaseAdmin
    .from('roles_staff')
    .select('puede_escanear')
    .eq('nombre', rol)
    .maybeSingle();

  // Un fallo de consulta no es una denegación de permiso. Si se despliega esta
  // función antes de aplicar la migración, responder 403 mandaría a todo el
  // staff a revisar permisos cuando el problema es de esquema.
  if (error) {
    return {
      allowed: false,
      error: `No se pudo comprobar el permiso de la función de staff: ${error.message}`,
    };
  }

  return { allowed: data?.puede_escanear === true };
}

/**
 * Resolves staff.id corresponding to a perfil_id.
 * 1. Checks public.staff where perfil_id = perfilId.
 * 2. Checks public.staff where id = perfilId (for backwards compatibility).
 * 3. Si no hay fila, devuelve error accionable. No da de alta solo: la función
 *    operativa no se puede deducir desde perfiles.rol.
 */
export async function resolveStaffId(
  supabaseAdmin: SupabaseClient,
  perfilId: string
): Promise<StaffResolution> {
  // 1. Lookup by perfil_id
  const { data: staffByPerfil, error: err1 } = await supabaseAdmin
    .from('staff')
    .select('id, rol')
    .eq('perfil_id', perfilId)
    .maybeSingle();

  if (!err1 && staffByPerfil?.id) {
    return {
      staffId: String(staffByPerfil.id),
      rol: staffByPerfil.rol ? String(staffByPerfil.rol) : undefined,
    };
  }

  // 2. Lookup by id
  const { data: staffById, error: err2 } = await supabaseAdmin
    .from('staff')
    .select('id, rol')
    .eq('id', perfilId)
    .maybeSingle();

  if (!err2 && staffById?.id) {
    return {
      staffId: String(staffById.id),
      rol: staffById.rol ? String(staffById.rol) : undefined,
    };
  }

  // 3. Sin fila en staff no se puede continuar, y no se da de alta sola.
  // staff.rol es una función operativa del catálogo roles_staff (Coordinación,
  // Logística, Registro...), no el nivel de permiso de perfiles.rol, así que no
  // hay forma de deducirla desde el perfil. Inventarla decidiría además quién
  // puede escanear, porque el permiso de escaneo depende de esa función.
  return {
    staffId: null,
    error:
      'Tu usuario no está dado de alta en el equipo de staff. Pide a coordinación que te registre y te asigne una función.',
  };
}
