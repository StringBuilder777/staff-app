declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    delete(key: string): void;
    toObject(): Record<string, string>;
  };
  export function serve(
    handler: (req: Request) => Response | Promise<Response>
  ): void;
  export function serve(
    options: { port?: number; onListen?: (params: { port: number; hostname: string }) => void },
    handler: (req: Request) => Response | Promise<Response>
  ): void;
}

declare module '@supabase/functions-js/edge-runtime.d.ts';

declare module '@supabase/supabase-js' {
  export interface User {
    id: string;
    email?: string;
    [key: string]: unknown;
  }

  export interface PostgrestResponse<T = Record<string, unknown>[]> {
    data: T | null;
    error: { message: string; details?: string; hint?: string; code?: string } | null;
  }

  export interface PostgrestSingleResponse<T = Record<string, unknown>> {
    data: T | null;
    error: { message: string; details?: string; hint?: string; code?: string } | null;
  }

  export interface PostgrestFilterBuilder<T = Record<string, unknown>[]> extends PromiseLike<PostgrestResponse<T>> {
    select(columns?: string): PostgrestFilterBuilder<T>;
    eq(column: string, value: unknown): PostgrestFilterBuilder<T>;
    is(column: string, value: unknown): PostgrestFilterBuilder<T>;
    single<R = Record<string, unknown>>(): Promise<PostgrestSingleResponse<R>>;
    maybeSingle<R = Record<string, unknown>>(): Promise<PostgrestSingleResponse<R>>;
  }

  export interface PostgrestQueryBuilder {
    select(columns?: string): PostgrestFilterBuilder<Record<string, unknown>[]>;
    insert(values: Record<string, unknown> | Record<string, unknown>[]): PostgrestFilterBuilder<Record<string, unknown>[]>;
    update(values: Record<string, unknown>): PostgrestFilterBuilder<Record<string, unknown>[]>;
    delete(): PostgrestFilterBuilder<Record<string, unknown>[]>;
  }

  export interface SupabaseAuthClient {
    getUser(jwt?: string): Promise<{ data: { user: User | null }; error: { message: string } | null }>;
  }

  export interface SupabaseClient {
    auth: SupabaseAuthClient;
    from(table: string): PostgrestQueryBuilder;
  }

  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: {
      auth?: {
        persistSession?: boolean;
        autoRefreshToken?: boolean;
      };
      global?: {
        headers?: Record<string, string>;
      };
    }
  ): SupabaseClient;
}
