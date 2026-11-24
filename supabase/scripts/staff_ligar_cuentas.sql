-- Staff: liga a cada persona del equipo de staff con su cuenta, por correo.
--
-- El panel da de alta al staff (nombre, función y correo) sin ligarlo a una
-- cuenta, y las funciones de la app buscan al staff por staff.perfil_id: sin
-- eso responden «Tu usuario no está dado de alta en el equipo de staff».
--
-- No es una migración: se ejecuta a mano en Supabase → SQL Editor, y otra vez
-- cada vez que se agregue a alguien en el panel o se le cree su cuenta. Solo
-- liga lo que no tiene duda: un correo que está una sola vez en staff, con una
-- cuenta que no usa ninguna otra fila. Devuelve cómo queda cada persona.
--
-- Para desligar una fila (por ejemplo, antes de borrar esa cuenta en Auth, que
-- falla mientras esté ligada): update public.staff set perfil_id = null
-- where id = '<id de la fila>';

update public.staff s
set perfil_id = p.id
from public.perfiles p
where s.perfil_id is null
  and lower(regexp_replace(p.correo::text, '[\s\u00a0]+', '', 'g'))
    = lower(regexp_replace(s.correo, '[\s\u00a0]+', '', 'g'))
  -- Las filas antiguas cuyo id es el de la cuenta ya funcionan así, y su
  -- cuenta no se le pasa a otra fila.
  and not exists (select 1 from public.perfiles x where x.id = s.id)
  and not exists (select 1 from public.staff o where o.perfil_id = p.id or o.id = p.id)
  and (select count(*) from public.staff d
       where lower(regexp_replace(d.correo, '[\s\u00a0]+', '', 'g'))
           = lower(regexp_replace(s.correo, '[\s\u00a0]+', '', 'g'))) = 1;

-- Primero quien tiene algún problema.
select * from (
  select
    s.nombre,
    s.rol as funcion,
    s.correo,
    case
      when coalesce(regexp_replace(s.correo, '[\s\u00a0]+', '', 'g'), '') = ''
        and cuenta.id is null
        then 'Sin correo en el panel: agrégalo y vuelve a ejecutar esto'
      when cuenta.id is null and por_correo.id is null
        then 'No hay cuenta con ese correo: créala en Cuentas o corrige el correo en el panel'
      when cuenta.id is null
        then 'No se pudo ligar: el correo está repetido en staff o esa cuenta ya es de otra fila'
      when s.perfil_id is not null
        and lower(regexp_replace(cuenta.correo::text, '[\s\u00a0]+', '', 'g'))
          is distinct from lower(regexp_replace(s.correo, '[\s\u00a0]+', '', 'g'))
        then 'Ligada a otra cuenta (' || cuenta.correo::text || '): si no es suya, desligala por su id'
      when cuenta.rol::text not in ('staff', 'admin')
        then 'La cuenta es «' || cuenta.rol::text || '»: dala de alta en Cuentas con ese correo como staff'
      when coalesce(r.puede_escanear, false) = false
        then 'Ligada, pero su función no puede escanear'
      else 'Lista para escanear'
    end as estado,
    s.id
  from public.staff s
  left join public.perfiles cuenta on cuenta.id = coalesce(s.perfil_id, s.id)
  left join public.perfiles por_correo
    on lower(regexp_replace(por_correo.correo::text, '[\s\u00a0]+', '', 'g'))
     = lower(regexp_replace(s.correo, '[\s\u00a0]+', '', 'g'))
  left join public.roles_staff r on r.nombre = s.rol
) personas
order by estado = 'Lista para escanear', nombre;
