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
