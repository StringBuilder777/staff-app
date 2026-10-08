-- SITEC: borra los accesos de UN asistente de prueba (entradas, comidas y
-- salidas de los dos días) para que se pueda volver a registrar.
--
-- No es una migración: se ejecuta a mano en Supabase → SQL Editor. Escribe el
-- nombre del asistente, o una parte que solo tenga él, en la línea marcada y
-- ejecútalo. No distingue mayúsculas, acentos ni espacios. Si el nombre
-- completo coincide exactamente con uno, se usa ese; si no, la parte escrita
-- tiene que coincidir con una sola persona. Si no coincide nadie o coinciden
-- varios, no borra nada y lo dice.
--
-- No toca a nadie más, ni al asistente, su tarjeta o su kit: la tarjeta sigue
-- valiendo. Devuelve a quién encontró y qué accesos tenía.

with buscado as (
  select btrim(regexp_replace(lower(translate(normalize(
      'ESCRIBE AQUÍ EL NOMBRE'  -- ← asistente de prueba
    , NFC), 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇáàäâéèëêíìïîóòöôúùüûñç', 'AAAAEEEEIIIIOOOOUUUUNCaaaaeeeeiiiioooouuuunc')),
    '[\s\u00a0]+', ' ', 'g')) as clave
),
candidatos as (
  select t.*
  from (
    select
      a.id,
      btrim(a.nombre || ' ' || coalesce(a.apellidos, '')) as asistente,
      concat_ws(', ',
        case when a.jueves_entrada_en is not null then 'jueves entrada' end,
        case when a.jueves_comida_en is not null then 'jueves comida' end,
        case when a.jueves_salida_en is not null then 'jueves salida' end,
        case when a.viernes_entrada_en is not null then 'viernes entrada' end,
        case when a.viernes_comida_en is not null then 'viernes comida' end,
        case when a.viernes_salida_en is not null then 'viernes salida' end
      ) as accesos,
      btrim(regexp_replace(lower(translate(normalize(a.nombre || ' ' || coalesce(a.apellidos, ''), NFC),
        'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇáàäâéèëêíìïîóòöôúùüûñç', 'AAAAEEEEIIIIOOOOUUUUNCaaaaeeeeiiiioooouuuunc')),
        '[\s\u00a0]+', ' ', 'g')) as clave
    from public.sitec_asistentes a
  ) t, buscado b
  where b.clave <> ''
    and strpos(t.clave, b.clave) > 0
),
exactos as (
  select c.id from candidatos c, buscado b where c.clave = b.clave
),
objetivo as (
  select id from exactos where (select count(*) from exactos) = 1
  union all
  select id from candidatos
  where (select count(*) from exactos) <> 1 and (select count(*) from candidatos) = 1
),
limpiado as (
  update public.sitec_asistentes a
  set
    jueves_entrada_en = null,
    jueves_entrada_registrado_por = null,
    jueves_comida_en = null,
    jueves_comida_registrado_por = null,
    jueves_salida_en = null,
    jueves_salida_registrado_por = null,
    viernes_entrada_en = null,
    viernes_entrada_registrado_por = null,
    viernes_comida_en = null,
    viernes_comida_registrado_por = null,
    viernes_salida_en = null,
    viernes_salida_registrado_por = null,
    nfc_ultimo_leido_en = null
  where a.id in (select id from objetivo)
  returning a.id
)
select
  c.asistente,
  nullif(c.accesos, '') as tenia,
  case
    when c.id in (select id from objetivo) then 'Accesos borrados'
    when exists (select 1 from objetivo) then 'No se tocó'
    else 'No se borró nada: coinciden ' || (select count(*) from candidatos)
      || '; escribe el nombre más completo'
  end as resultado
from candidatos c
union all
select
  '(nadie)',
  null,
  case
    when (select clave from buscado) = '' then 'No se borró nada: escribe un nombre'
    else 'No se borró nada: nadie coincide con ese nombre'
  end
where not exists (select 1 from candidatos)
order by 1;
