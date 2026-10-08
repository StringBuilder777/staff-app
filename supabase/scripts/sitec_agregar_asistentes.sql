-- SITEC: da de alta, con su kit, a quien se inscribe después de la carga
-- inicial.
--
-- No es una migración: se ejecuta a mano. Pégalo en Supabase → SQL Editor,
-- cambia ahí la lista de abajo, una fila por persona, y ejecútalo. No escribas
-- los nombres en este archivo: está en el repositorio. El kit es premium,
-- basico o general (da igual mayúsculas o acento). Si no quieres separar el
-- nombre, escríbelo completo en el primer campo y deja '' en apellidos.
--
-- Quien ya esté (mismo nombre completo, sin distinguir mayúsculas, acentos ni
-- espacios) no se duplica: solo se le pone el kit de la lista. Si falta un kit,
-- está mal escrito o la misma persona aparece con dos kits distintos, Supabase
-- avisa con «sitec_asistentes_kit_check» y no se aplica nada. Los nuevos
-- aparecen en el Registro de SITEC de la app para escribirles la tarjeta.

with lista (nombre, apellidos, kit) as (
  values
    -- Una fila por persona, separadas por comas. Por ejemplo:
    -- ('Ana Sofía', 'Treviño Garza', 'basico'),
    ('', '', '')
),
limpia as (
  select
    coalesce(nullif(btrim(nombre), ''), nullif(btrim(apellidos), '')) as nombre,
    case when btrim(nombre) <> '' then nullif(btrim(apellidos), '') end as apellidos,
    lower(translate(btrim(coalesce(kit, '')), 'ÁÉÍÓÚáéíóú', 'AEIOUaeiou')) as kit,
    btrim(regexp_replace(lower(translate(normalize(coalesce(nombre, '') || ' ' || coalesce(apellidos, ''), NFC),
      'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇáàäâéèëêíìïîóòöôúùüûñç', 'AAAAEEEEIIIIOOOOUUUUNCaaaaeeeeiiiioooouuuunc')),
      '[\s\u00a0]+', ' ', 'g')) as clave
  from lista
),
nuevos as (
  -- Una fila por persona. Con dos kits distintos para la misma persona, el
  -- kit «distinto» no pasa el check y no se aplica nada.
  select distinct on (clave)
    nombre,
    apellidos,
    case when min(kit) over w = max(kit) over w then kit else 'distinto' end as kit,
    clave
  from limpia
  where clave <> ''
  window w as (partition by clave)
  order by clave, nombre, apellidos
),
tabla as (
  select
    a.id,
    btrim(regexp_replace(lower(translate(normalize(a.nombre || ' ' || coalesce(a.apellidos, ''), NFC),
      'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇáàäâéèëêíìïîóòöôúùüûñç', 'AAAAEEEEIIIIOOOOUUUUNCaaaaeeeeiiiioooouuuunc')),
      '[\s\u00a0]+', ' ', 'g')) as clave
  from public.sitec_asistentes a
),
con_kit as (
  update public.sitec_asistentes a
  set kit = n.kit
  from tabla t
  join nuevos n on n.clave = t.clave
  where a.id = t.id
    and a.kit is distinct from n.kit
  returning a.id
),
altas as (
  insert into public.sitec_asistentes (nombre, apellidos, kit)
  select n.nombre, n.apellidos, n.kit
  from nuevos n
  where not exists (select 1 from tabla t where t.clave = n.clave)
  returning id
)
select
  btrim(n.nombre || ' ' || coalesce(n.apellidos, '')) as asistente,
  n.kit,
  case
    when exists (select 1 from tabla t where t.clave = n.clave) then 'Ya estaba: se le pone este kit'
    else 'Dado de alta'
  end as resultado
from nuevos n
union all
select '(la lista está vacía)', null, 'No se hizo nada'
where not exists (select 1 from nuevos)
order by 1;
