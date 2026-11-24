-- Hackathon: borra los accesos y las salidas de UN participante de prueba
-- (check-in, cena, desayuno, comida, check-out y sus salidas y regresos) para
-- que se pueda volver a registrar. Sirve para probar las pulseras NFC antes
-- del evento sin dejar a nadie con el check-in hecho o marcado «fuera».
--
-- No es una migración: se ejecuta a mano en Supabase → SQL Editor, después de
-- hack_salidas_y_comida_viernes.sql. Escribe el nombre del participante, o una
-- parte que solo tenga él, en la línea marcada y ejecútalo. No distingue
-- mayúsculas, acentos ni espacios. Si el nombre completo coincide exactamente
-- con uno, se usa ese; si no, la parte escrita tiene que coincidir con una sola
-- persona. Si no coincide nadie o coinciden varios, no borra nada y lo dice.
--
-- No toca a nadie más, ni al participante, su equipo o su tarjeta: la tarjeta
-- sigue valiendo. Devuelve a quién encontró y qué tenía registrado.

with buscado as (
  select btrim(regexp_replace(lower(translate(normalize(
      'ESCRIBE AQUÍ EL NOMBRE'  -- ← participante de prueba
    , NFC), 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇáàäâéèëêíìïîóòöôúùüûñç', 'AAAAEEEEIIIIOOOOUUUUNCaaaaeeeeiiiioooouuuunc')),
    '[\s\u00a0]+', ' ', 'g')) as clave
),
candidatos as (
  select t.*
  from (
    select
      i.id,
      btrim(i.nombre || ' ' || coalesce(i.apellido, '')) as participante,
      e.nombre as equipo,
      concat_ws(', ',
        case when i.checkin_en is not null then 'check-in' end,
        case when i.cena_en is not null then 'cena' end,
        case when i.desayuno_en is not null then 'desayuno' end,
        case when i.comida_en is not null then 'comida' end,
        case when i.checkout_en is not null then 'check-out' end,
        (select case when count(*) > 0 then count(*) || ' salida(s)' end
           from public.hackathon_salidas s where s.integrante_id = i.id)
      ) as accesos,
      btrim(regexp_replace(lower(translate(normalize(i.nombre || ' ' || coalesce(i.apellido, ''), NFC),
        'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇáàäâéèëêíìïîóòöôúùüûñç', 'AAAAEEEEIIIIOOOOUUUUNCaaaaeeeeiiiioooouuuunc')),
        '[\s\u00a0]+', ' ', 'g')) as clave
    from public.integrantes i
    left join public.equipos e on e.id = i.equipo_id
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
  update public.integrantes i
  set
    checkin_en = null,
    checkin_registrado_por = null,
    cena_en = null,
    cena_registrado_por = null,
    desayuno_en = null,
    desayuno_registrado_por = null,
    comida_en = null,
    comida_registrado_por = null,
    checkout_en = null,
    checkout_registrado_por = null,
    nfc_ultimo_leido_en = null
  where i.id in (select id from objetivo)
  returning i.id
),
salidas_borradas as (
  delete from public.hackathon_salidas s
  where s.integrante_id in (select id from objetivo)
  returning s.id
)
select
  c.participante,
  c.equipo,
  nullif(c.accesos, '') as tenia,
  case
    when c.id in (select id from objetivo) then 'Accesos y salidas borrados'
    when exists (select 1 from objetivo) then 'No se tocó'
    else 'No se borró nada: coinciden ' || (select count(*) from candidatos)
      || '; escribe el nombre más completo'
  end as resultado
from candidatos c
union all
select
  '(nadie)',
  null,
  null,
  case
    when (select clave from buscado) = '' then 'No se borró nada: escribe un nombre'
    else 'No se borró nada: nadie coincide con ese nombre'
  end
where not exists (select 1 from candidatos)
order by 1;
