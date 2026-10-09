-- ============================================================================
-- Cambios del 2026-10-08 para pegar en Supabase → SQL Editor, de una vez.
--
--   1. Hackathon: cena (viernes) y check-out (sábado) por integrante.
--   2. SITEC: fin de la comida del viernes (viernes_comida pasa a ser el inicio).
--   3. Hackathon: tabla de salidas y regresos (hackathon_salidas).
--   4. Panel de admin: el comité puede leer SITEC, el fin de la comida y las
--      salidas desde /admin.
--
-- Todo es aditivo: no borra tablas, columnas ni datos. Solo añade columnas y
-- una tabla nueva, y da permiso de lectura al comité. Se puede correr más de
-- una vez: lo que ya existe se deja como está («if not exists»). Los únicos
-- «revoke» y «drop policy» son sobre permisos de lectura de sitec_asistentes y
-- hackathon_salidas, para volver a crearlos iguales; ninguno toca filas.
--
-- Córrelo ANTES de desplegar las Edge Functions nuevas y de repartir la APK.
-- Sale de supabase/migrations/20261007120000, 20261008120000 y 20261008121000
-- de la app de staff, y de los bloques del 2026-10-04 y del 2026-10-08 de
-- database/alter.sql del sitio (road-to-tech).
-- ============================================================================

-- ── 1. Hackathon: cena y check-out ──────────────────────────────────────────────

-- Accesos del hackathon final: la cena del viernes y el check-out del sábado.
--
-- Siguen la forma de checkin, desayuno y comida: la hora del acceso y el staff
-- que lo registró. Es aditiva: no toca columnas ni datos que ya existen.

alter table public.integrantes
  add column if not exists cena_en timestamp with time zone,
  add column if not exists cena_registrado_por uuid references public.staff(id),
  add column if not exists checkout_en timestamp with time zone,
  add column if not exists checkout_registrado_por uuid references public.staff(id);

create index if not exists integrantes_cena_registrado_por_idx
  on public.integrantes (cena_registrado_por);

create index if not exists integrantes_checkout_registrado_por_idx
  on public.integrantes (checkout_registrado_por);

-- ── 2. SITEC: fin de la comida del viernes ──────────────────────────────────────

-- SITEC: la comida del viernes se registra al empezar y al terminar.
--
-- viernes_comida sigue siendo la misma columna y ahora es el inicio de la
-- comida: la app y el lector web la muestran como «Inicio comida». Así, lo que
-- marque un teléfono que aún no se ha actualizado queda como inicio, que es lo
-- que registraba. El fin es un par nuevo con la forma de los demás puntos: la
-- hora y el staff que lo registró.
--
-- Es aditiva: no toca columnas ni datos que ya existen.

alter table public.sitec_asistentes
  add column if not exists viernes_comida_fin_en timestamp with time zone,
  add column if not exists viernes_comida_fin_registrado_por uuid references public.staff(id);

create index if not exists sitec_asistentes_viernes_comida_fin_registrado_por_idx
  on public.sitec_asistentes (viernes_comida_fin_registrado_por);

comment on column public.sitec_asistentes.viernes_comida_en is
  'Inicio de la comida del viernes. La escribe staff-sitec-scan-nfc con accessType viernes_comida.';

comment on column public.sitec_asistentes.viernes_comida_fin_en is
  'Fin de la comida del viernes. La escribe staff-sitec-scan-nfc con accessType viernes_comida_fin.';

-- ── 3. Hackathon: salidas y regresos ────────────────────────────────────────────

-- Hackathon final: salidas y regresos durante el evento.
--
-- A diferencia de los demás puntos, la salida no se registra una sola vez. La
-- primera lectura en el punto «Salida» abre una salida (la persona queda
-- fuera) y la siguiente la cierra con la hora de regreso. Cada salida es una
-- fila, así que se conserva el historial completo y quien está fuera ahora es
-- quien tiene una fila sin regreso_en.
--
-- La escribe staff-scan-nfc con accessType salida. Es aditiva: no toca tablas,
-- columnas ni datos que ya existen.

create table if not exists public.hackathon_salidas (
  id uuid primary key default gen_random_uuid(),
  -- Si se borra a un integrante (o su equipo), sus salidas se van con él: no
  -- deben impedir que el comité lo borre.
  integrante_id uuid not null references public.integrantes(id) on delete cascade,
  salio_en timestamp with time zone not null default now(),
  salida_registrado_por uuid references public.staff(id),
  regreso_en timestamp with time zone,
  regreso_registrado_por uuid references public.staff(id)
);

comment on table public.hackathon_salidas is
  'Salidas de los integrantes durante el hackathon. Sin regreso_en, la persona sigue fuera. La escribe staff-scan-nfc.';

-- Id de la lectura que abrió la salida y de la que la cerró. La app manda uno
-- distinto por lectura; si la respuesta se pierde (sin red, timeout) y la app
-- reintenta con el mismo id, staff-scan-nfc lo reconoce y devuelve lo que ya
-- se registró en vez de alternar otra vez. Van aparte del CREATE para que
-- volver a correr este archivo también las añada.
alter table public.hackathon_salidas
  add column if not exists salida_lectura_id uuid,
  add column if not exists regreso_lectura_id uuid;

create unique index if not exists hackathon_salidas_salida_lectura_id_idx
  on public.hackathon_salidas (salida_lectura_id);

create unique index if not exists hackathon_salidas_regreso_lectura_id_idx
  on public.hackathon_salidas (regreso_lectura_id);

-- Una sola salida abierta por persona. Si dos teléfonos leen la misma tarjeta
-- a la vez, el segundo INSERT falla en vez de abrir otra.
create unique index if not exists hackathon_salidas_una_abierta_idx
  on public.hackathon_salidas (integrante_id)
  where regreso_en is null;

-- El último regreso de cada persona, para reconocer una doble lectura.
create index if not exists hackathon_salidas_integrante_regreso_en_idx
  on public.hackathon_salidas (integrante_id, regreso_en desc nulls last);

-- Índices de las FK hacia staff, como en integrantes.
create index if not exists hackathon_salidas_salida_registrado_por_idx
  on public.hackathon_salidas (salida_registrado_por);

create index if not exists hackathon_salidas_regreso_registrado_por_idx
  on public.hackathon_salidas (regreso_registrado_por);

-- Igual que sitec_asistentes: RLS sin políticas deja fuera a anon y
-- authenticated, y solo las Edge Functions, con la service role, escriben.
-- La lectura del comité para el panel de admin se concede aparte, con una
-- política, desde el script del panel.
alter table public.hackathon_salidas enable row level security;

grant select, insert, update on public.hackathon_salidas to service_role;

-- ── 4. Panel de admin: lectura del comité ───────────────────────────────────────

-- ── 2026-10-04 · El comité lee la asistencia de SITEC desde el panel ────────
--
--  `sitec_asistentes` la crea la migración
--  `20261001120000_create_sitec_asistentes` de la app de staff, con RLS y sin
--  ninguna política: la escriben y la leen solo sus Edge Functions, con la
--  service role. `/admin/sitec` necesita leerla desde el navegador con la
--  sesión del comité, y nada más que leerla.
--
--  La fila la decide la política, con el mismo criterio que
--  `integrantes_lectura`: `es_comite()`, envuelta en un `select` para que se
--  evalúe una vez por consulta y no una por asistente. Las columnas, el
--  permiso: el panel no necesita `nfc_token` —la credencial de la pulsera— ni
--  quién registró cada punto, así que se retira el permiso de tabla que
--  Supabase concede por defecto a `anon` y `authenticated` y a
--  `authenticated` se le devuelve solo el de las columnas que se pintan. Una
--  consulta que pida `nfc_token` falla en vez de devolverlo. Escribir sigue
--  siendo cosa de la service role.
--
--  Retirar el permiso de tabla retira también los de columna, así que el
--  bloque se puede volver a correr. Si la base se levanta solo con estos
--  archivos, sin las migraciones de la app de staff, la tabla no existe y el
--  bloque no hace nada: hay que volver a correrlo después de esa migración.

do $$
begin
  if to_regclass('public.sitec_asistentes') is null then
    raise notice 'No existe public.sitec_asistentes: se omite su lectura para el comité.';
    return;
  end if;

  revoke all on table public.sitec_asistentes from anon, authenticated;
  grant select (
    id, nombre, apellidos,
    jueves_entrada_en, jueves_comida_en, jueves_salida_en,
    viernes_entrada_en, viernes_salida_en, viernes_comida_en
  ) on table public.sitec_asistentes to authenticated;

  drop policy if exists sitec_asistentes_lectura on public.sitec_asistentes;
  create policy sitec_asistentes_lectura on public.sitec_asistentes
    for select to authenticated
    using ((select public.es_comite()));
end;
$$;


-- ── 2026-10-08 · Fin de la comida del viernes y salidas del hackathon ───────
--
--  La app de staff añade dos cosas que el panel lee:
--
--  · `sitec_asistentes.viernes_comida_fin_en` (migración
--    `20261008120000_add_sitec_viernes_comida_fin`): el viernes la comida de
--    SITEC tiene inicio (`viernes_comida_en`, la de siempre) y fin. El bloque
--    del 2026-10-04 concede al comité columna por columna, así que la nueva
--    necesita su propio permiso. Si se vuelve a correr aquel bloque, hay que
--    correr también este: aquel retira primero todos los permisos de columna.
--
--  · `hackathon_salidas` (migración `20261008121000_create_hackathon_salidas`):
--    una fila por cada salida del hackathon, con su regreso. Nace con RLS y sin
--    políticas, como `sitec_asistentes`. `/admin/hack` la lee con la sesión
--    del comité, con el mismo criterio que `integrantes_lectura`, y solo las
--    columnas que pinta. Escribir sigue siendo cosa de la service role.
--
--  Si la base se levanta sin las migraciones de la app de staff, la columna o
--  la tabla no existen y su parte se omite: hay que volver a correr el bloque
--  después de esas migraciones.

do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name = 'sitec_asistentes'
       and column_name = 'viernes_comida_fin_en'
  ) then
    grant select (viernes_comida_fin_en) on table public.sitec_asistentes to authenticated;
  else
    raise notice 'No existe sitec_asistentes.viernes_comida_fin_en: se omite su lectura para el comité.';
  end if;

  if to_regclass('public.hackathon_salidas') is null then
    raise notice 'No existe public.hackathon_salidas: se omite su lectura para el comité.';
    return;
  end if;

  revoke all on table public.hackathon_salidas from anon, authenticated;
  grant select (
    id, integrante_id, salio_en, regreso_en,
    salida_registrado_por, regreso_registrado_por
  ) on table public.hackathon_salidas to authenticated;

  drop policy if exists hackathon_salidas_lectura on public.hackathon_salidas;
  create policy hackathon_salidas_lectura on public.hackathon_salidas
    for select to authenticated
    using ((select public.es_comite()));
end;
$$;

-- PostgREST vuelve a leer el esquema para ver al momento lo nuevo.
notify pgrst, 'reload schema';
