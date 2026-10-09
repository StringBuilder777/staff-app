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
