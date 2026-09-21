-- Permiso de validación de accesos NFC por función operativa.
--
-- staff.rol referencia roles_staff.nombre y describe la función de la persona
-- (Coordinación, Logística, ...), no su nivel de permiso, que vive en
-- perfiles.rol. Sin esta columna cualquier integrante del staff podía validar
-- accesos, incluidos Mentor, Jurado y Comunicación, que no operan los filtros.
--
-- Al ser un dato de catálogo, cambiar la política es un UPDATE y no exige
-- volver a desplegar las Edge Functions.

alter table public.roles_staff
  add column if not exists puede_escanear boolean not null default false;

comment on column public.roles_staff.puede_escanear is
  'Si es true, esta función puede validar accesos (checkin, desayuno, comida) leyendo NFC.';

update public.roles_staff
set puede_escanear = true
where nombre in (
  'Coordinación',
  'Logística',
  'Registro',
  'Alimentos',
  'Soporte técnico'
);
