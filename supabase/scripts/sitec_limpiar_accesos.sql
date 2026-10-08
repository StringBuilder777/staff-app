-- SITEC: borra los accesos de prueba (entradas, comidas y salidas de los dos
-- días) para empezar el evento en limpio.
--
-- No es una migración: se ejecuta a mano en Supabase → SQL Editor, solo
-- cuando haga falta.
--
-- Vacía lo registrado ANTES de la hora de corte. Con now() borra todo lo
-- registrado hasta ahora, que es lo que se quiere antes del evento. Si el
-- evento ya empezó, pon su hora de inicio en lugar de now(), por ejemplo
-- timestamptz '2026-10-08 08:00-06' (hora de Saltillo), y no se pierde ningún
-- acceso real.
--
-- No toca a los asistentes, sus tarjetas ni su kit: las tarjetas escritas
-- siguen valiendo. Devuelve a quién se le borró algo.

with corte as (
  select now() as hasta  -- ← hora de corte
)
update public.sitec_asistentes a
set
  jueves_entrada_en = case when a.jueves_entrada_en < c.hasta then null else a.jueves_entrada_en end,
  jueves_entrada_registrado_por = case when a.jueves_entrada_en < c.hasta then null else a.jueves_entrada_registrado_por end,
  jueves_comida_en = case when a.jueves_comida_en < c.hasta then null else a.jueves_comida_en end,
  jueves_comida_registrado_por = case when a.jueves_comida_en < c.hasta then null else a.jueves_comida_registrado_por end,
  jueves_salida_en = case when a.jueves_salida_en < c.hasta then null else a.jueves_salida_en end,
  jueves_salida_registrado_por = case when a.jueves_salida_en < c.hasta then null else a.jueves_salida_registrado_por end,
  viernes_entrada_en = case when a.viernes_entrada_en < c.hasta then null else a.viernes_entrada_en end,
  viernes_entrada_registrado_por = case when a.viernes_entrada_en < c.hasta then null else a.viernes_entrada_registrado_por end,
  viernes_comida_en = case when a.viernes_comida_en < c.hasta then null else a.viernes_comida_en end,
  viernes_comida_registrado_por = case when a.viernes_comida_en < c.hasta then null else a.viernes_comida_registrado_por end,
  viernes_salida_en = case when a.viernes_salida_en < c.hasta then null else a.viernes_salida_en end,
  viernes_salida_registrado_por = case when a.viernes_salida_en < c.hasta then null else a.viernes_salida_registrado_por end,
  nfc_ultimo_leido_en = case when a.nfc_ultimo_leido_en < c.hasta then null else a.nfc_ultimo_leido_en end
from corte c
where a.jueves_entrada_en < c.hasta
   or a.jueves_comida_en < c.hasta
   or a.jueves_salida_en < c.hasta
   or a.viernes_entrada_en < c.hasta
   or a.viernes_comida_en < c.hasta
   or a.viernes_salida_en < c.hasta
   or a.nfc_ultimo_leido_en < c.hasta
returning btrim(a.nombre || ' ' || coalesce(a.apellidos, '')) as asistente;
