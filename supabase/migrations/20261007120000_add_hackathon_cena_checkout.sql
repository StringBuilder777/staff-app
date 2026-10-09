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
