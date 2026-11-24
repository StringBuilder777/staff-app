-- SITEC: kit que compró cada asistente, para que el staff lo vea junto al
-- nombre en las entradas, comidas y salidas.
--
-- Se guarda en minúsculas y sin acento (premium, basico, general); la app y el
-- lector web lo muestran como «Premium», «Básico» o «General». Un asistente sin
-- kit (null) no está en el registro de ventas, y el lector solo muestra su
-- nombre.
--
-- Los valores salen del CSV de ventas, con el SQL que genera
-- supabase/scripts/sitec_kits_desde_csv.py.

alter table public.sitec_asistentes
  add column if not exists kit text
    constraint sitec_asistentes_kit_check
    check (kit in ('premium', 'basico', 'general'));

comment on column public.sitec_asistentes.kit is
  'Kit comprado según el registro de ventas: premium, basico o general. Lo devuelve staff-sitec-scan-nfc.';
