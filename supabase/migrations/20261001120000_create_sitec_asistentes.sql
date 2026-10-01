-- SITEC: asistentes y sus accesos por día, en una tabla propia.
--
-- SITEC no comparte modelo con el hackathon: no hay equipos y sus asistentes
-- se cargan aparte. Tenerlos en su propia tabla deja intactos integrantes y la
-- lógica de staff-scan-nfc; la validación vive en staff-sitec-scan-nfc.
--
-- Cada punto de acceso es un par de columnas, igual que checkin, desayuno y
-- comida en integrantes: cuándo se registró y qué staff lo registró. Una
-- segunda lectura en el mismo punto se rechaza porque la columna ya tiene hora.
--
-- Los asistentes se cargarán más adelante. Basta con insertar nombre y
-- apellidos: el token NFC se genera solo.

create table if not exists public.sitec_asistentes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  apellidos text,
  nfc_token uuid not null unique default gen_random_uuid(),
  nfc_activa boolean not null default true,
  nfc_emitida_en timestamp with time zone,
  nfc_ultimo_leido_en timestamp with time zone,
  jueves_entrada_en timestamp with time zone,
  jueves_entrada_registrado_por uuid references public.staff(id),
  jueves_comida_en timestamp with time zone,
  jueves_comida_registrado_por uuid references public.staff(id),
  jueves_salida_en timestamp with time zone,
  jueves_salida_registrado_por uuid references public.staff(id),
  viernes_entrada_en timestamp with time zone,
  viernes_entrada_registrado_por uuid references public.staff(id),
  viernes_salida_en timestamp with time zone,
  viernes_salida_registrado_por uuid references public.staff(id),
  viernes_comida_en timestamp with time zone,
  viernes_comida_registrado_por uuid references public.staff(id),
  creado_en timestamp with time zone not null default now()
);

comment on table public.sitec_asistentes is
  'Asistentes de SITEC y sus accesos por día y punto. La escribe staff-sitec-scan-nfc.';

-- Índices de las FK hacia staff, como en integrantes: sin ellos, borrar o
-- actualizar un staff recorre la tabla entera.
create index if not exists sitec_asistentes_jueves_entrada_registrado_por_idx
  on public.sitec_asistentes (jueves_entrada_registrado_por);

create index if not exists sitec_asistentes_jueves_comida_registrado_por_idx
  on public.sitec_asistentes (jueves_comida_registrado_por);

create index if not exists sitec_asistentes_jueves_salida_registrado_por_idx
  on public.sitec_asistentes (jueves_salida_registrado_por);

create index if not exists sitec_asistentes_viernes_entrada_registrado_por_idx
  on public.sitec_asistentes (viernes_entrada_registrado_por);

create index if not exists sitec_asistentes_viernes_salida_registrado_por_idx
  on public.sitec_asistentes (viernes_salida_registrado_por);

create index if not exists sitec_asistentes_viernes_comida_registrado_por_idx
  on public.sitec_asistentes (viernes_comida_registrado_por);

-- Solo las Edge Functions, con la service role, leen y escriben aquí. RLS sin
-- políticas deja fuera a anon y authenticated: la anon key viaja dentro de la
-- app y, sin esto, cualquiera podría leer asistentes o marcar accesos por la
-- API REST.
alter table public.sitec_asistentes enable row level security;

-- Permisos explícitos para la service role, para no depender de que el
-- proyecto exponga automáticamente las tablas nuevas (auto_expose_new_tables).
grant select, update on public.sitec_asistentes to service_role;

-- SITEC usa el mismo permiso de escaneo que el hackathon.
comment on column public.roles_staff.puede_escanear is
  'Si es true, esta función puede validar accesos leyendo NFC: checkin, desayuno y comida del hackathon, y los puntos de SITEC.';
