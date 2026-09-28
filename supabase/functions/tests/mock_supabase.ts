import type {
  SupabaseClient,
  PostgrestFilterBuilder,
  PostgrestQueryBuilder,
  PostgrestResponse,
  PostgrestSingleResponse,
} from '@supabase/supabase-js';

export interface MockDatabaseState {
  users: Array<{ id: string; email?: string }>;
  perfiles: Array<{ id: string; rol: string; [key: string]: unknown }>;
  staff: Array<{ id: string; perfil_id?: string; [key: string]: unknown }>;
  /** Catálogo de funciones operativas. staff.rol apunta aquí por `nombre`. */
  roles_staff: Array<{
    id: string;
    nombre: string;
    puede_escanear: boolean;
    [key: string]: unknown;
  }>;
  equipos: Array<{ id: string; nombre: string; qr_token?: string; [key: string]: unknown }>;
  integrantes: Array<{
    id: string;
    nombre: string;
    apellidos?: string | null;
    equipo_id?: string | null;
    nfc_token?: string | null;
    nfc_activa?: boolean;
    nfc_emitida_en?: string | null;
    nfc_ultimo_leido_en?: string | null;
    checkin_en?: string | null;
    checkin_registrado_por?: string | null;
    desayuno_en?: string | null;
    desayuno_registrado_por?: string | null;
    comida_en?: string | null;
    comida_registrado_por?: string | null;
    // Sensitive fields to test that they are NEVER exposed:
    alergias?: string | null;
    telefono?: string | null;
    contacto_emergencia?: string | null;
    contacto_emergencia_telefono?: string | null;
    email?: string | null;
    [key: string]: unknown;
  }>;
}

export function createInitialMockDatabaseState(): MockDatabaseState {
  return {
    users: [
      { id: 'user-staff-1', email: 'staff@event.com' },
      { id: 'user-admin-1', email: 'admin@event.com' },
      { id: 'user-part-1', email: 'participant@event.com' },
    ],
    perfiles: [
      { id: 'user-staff-1', rol: 'staff', nombre: 'Carlos Staff' },
      { id: 'user-admin-1', rol: 'admin', nombre: 'Admin Master' },
      { id: 'user-part-1', rol: 'participante', nombre: 'Pedro Participante' },
    ],
    staff: [
      // `rol` es la función operativa del catálogo roles_staff, no el nivel de
      // permiso de perfiles.rol.
      { id: 'staff-uuid-1', perfil_id: 'user-staff-1', rol: 'Registro' },
      { id: 'staff-uuid-2', perfil_id: 'user-admin-1', rol: 'Coordinación' },
    ],
    roles_staff: [
      { id: 'rol-uuid-1', nombre: 'Coordinación', puede_escanear: true },
      { id: 'rol-uuid-2', nombre: 'Registro', puede_escanear: true },
      // Mentor no opera los filtros de acceso: sirve para probar el rechazo.
      { id: 'rol-uuid-3', nombre: 'Mentor', puede_escanear: false },
    ],
    equipos: [
      { id: 'equipo-uuid-1', nombre: 'Equipo Boreal', qr_token: 'valid-qr-token-123' },
    ],
    integrantes: [
      {
        id: 'int-uuid-1',
        nombre: 'Ana',
        apellidos: 'Torres',
        equipo_id: 'equipo-uuid-1',
        nfc_token: 'valid-nfc-token-123',
        nfc_activa: true,
        nfc_emitida_en: '2026-09-14T10:00:00.000Z',
        nfc_ultimo_leido_en: null,
        checkin_en: null,
        checkin_registrado_por: null,
        desayuno_en: null,
        desayuno_registrado_por: null,
        comida_en: null,
        comida_registrado_por: null,
        // Sensitive data:
        alergias: 'Penicilina y nueces',
        telefono: '+528112345678',
        contacto_emergencia: 'Laura Torres (Madre)',
        contacto_emergencia_telefono: '+528187654321',
        email: 'ana.torres@example.com',
      },
      {
        id: 'int-uuid-2',
        nombre: 'Luis',
        apellidos: 'Herrera',
        equipo_id: 'equipo-uuid-1',
        nfc_token: 'inactive-nfc-token-456',
        nfc_activa: false,
        nfc_emitida_en: null,
        nfc_ultimo_leido_en: null,
        checkin_en: null,
        checkin_registrado_por: null,
        desayuno_en: null,
        desayuno_registrado_por: null,
        comida_en: null,
        comida_registrado_por: null,
        alergias: 'Ninguna',
        telefono: '+528119876543',
        email: 'luis.herrera@example.com',
      },
    ],
  };
}

export function createMockSupabaseClient(initialState: MockDatabaseState): SupabaseClient {
  const db = initialState;

  function getTableData(table: string): Array<Record<string, unknown>> {
    switch (table) {
      case 'perfiles':
        return db.perfiles;
      case 'staff':
        return db.staff;
      case 'roles_staff':
        return db.roles_staff;
      case 'equipos':
        return db.equipos;
      case 'integrantes':
        return db.integrantes;
      default:
        return [];
    }
  }

  function makeFilterBuilder(
    recordsGetter: () => Array<Record<string, unknown>>,
    conditions: Array<(row: Record<string, unknown>) => boolean> = []
  ): PostgrestFilterBuilder<Record<string, unknown>[]> {
    const builder: PostgrestFilterBuilder<Record<string, unknown>[]> = {
      select(_columns?: string) {
        return builder;
      },
      eq(column: string, value: unknown) {
        conditions.push((row) => row[column] === value);
        return builder;
      },
      is(column: string, value: unknown) {
        conditions.push((row) => {
          if (value === null) {
            return row[column] === null || row[column] === undefined;
          }
          return row[column] === value;
        });
        return builder;
      },
      async single<R = Record<string, unknown>>(): Promise<PostgrestSingleResponse<R>> {
        const rows = recordsGetter().filter((row) => conditions.every((fn) => fn(row)));
        if (rows.length === 0) {
          return { data: null, error: { message: 'Row not found' } };
        }
        return { data: rows[0] as unknown as R, error: null };
      },
      async maybeSingle<R = Record<string, unknown>>(): Promise<PostgrestSingleResponse<R>> {
        const rows = recordsGetter().filter((row) => conditions.every((fn) => fn(row)));
        if (rows.length === 0) {
          return { data: null, error: null };
        }
        return { data: rows[0] as unknown as R, error: null };
      },
      then<TResult1 = PostgrestResponse<Record<string, unknown>[]>, TResult2 = never>(
        onfulfilled?: ((value: PostgrestResponse<Record<string, unknown>[]>) => TResult1 | PromiseLike<TResult1>) | null,
        onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
      ): Promise<TResult1 | TResult2> {
        const rows = recordsGetter().filter((row) => conditions.every((fn) => fn(row)));
        const res: PostgrestResponse<Record<string, unknown>[]> = { data: rows, error: null };
        return Promise.resolve(res).then(onfulfilled, onrejected);
      },
    };

    return builder;
  }

  const client: SupabaseClient = {
    auth: {
      async getUser(jwt?: string) {
        if (!jwt) {
          return { data: { user: null }, error: { message: 'Missing JWT' } };
        }
        if (jwt === 'jwt-staff-valid') {
          return { data: { user: { id: 'user-staff-1', email: 'staff@event.com' } }, error: null };
        }
        if (jwt === 'jwt-admin-valid') {
          return { data: { user: { id: 'user-admin-1', email: 'admin@event.com' } }, error: null };
        }
        if (jwt === 'jwt-part-valid') {
          return { data: { user: { id: 'user-part-1', email: 'participant@event.com' } }, error: null };
        }
        return { data: { user: null }, error: { message: 'Invalid token' } };
      },
    },
    from(table: string): PostgrestQueryBuilder {
      return {
        select(_columns?: string) {
          return makeFilterBuilder(() => getTableData(table));
        },
        insert(values: Record<string, unknown> | Record<string, unknown>[]) {
          const list = Array.isArray(values) ? values : [values];
          const created: Array<Record<string, unknown>> = [];
          for (const item of list) {
            const newItem = { id: (item.id as string) || crypto.randomUUID(), ...item };
            getTableData(table).push(newItem);
            created.push(newItem);
          }
          return makeFilterBuilder(() => created);
        },
        update(updates: Record<string, unknown>) {
          const conditions: Array<(row: Record<string, unknown>) => boolean> = [];
          const updatedRows: Array<Record<string, unknown>> = [];

          const builder = makeFilterBuilder(
            () => updatedRows,
            conditions
          );

          builder.then = function <TResult1 = PostgrestResponse<Record<string, unknown>[]>, TResult2 = never>(
            onfulfilled?: ((value: PostgrestResponse<Record<string, unknown>[]>) => TResult1 | PromiseLike<TResult1>) | null,
            onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null
          ) {
            const tableRows = getTableData(table);
            for (const row of tableRows) {
              if (conditions.every((fn) => fn(row))) {
                Object.assign(row, updates);
                updatedRows.push({ ...row });
              }
            }
            const res: PostgrestResponse<Record<string, unknown>[]> = { data: updatedRows, error: null };
            return Promise.resolve(res).then(onfulfilled, onrejected);
          };

          return builder;
        },
        delete() {
          return makeFilterBuilder(() => []);
        },
      };
    },
  };

  return client;
}
