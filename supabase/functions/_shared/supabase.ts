import { createClient, type SupabaseClient } from '@supabase/supabase-js';

/**
 * Creates a Supabase client using SUPABASE_SERVICE_ROLE_KEY.
 * This key is NEVER exposed to the client and is only used internally by Edge Functions
 * after validating the user's JWT and staff/admin role.
 */
export function getSupabaseAdminClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('Variables de entorno SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY no configuradas');
  }

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}
