#!/usr/bin/env python3
"""Genera el SQL que carga el kit de los asistentes de SITEC desde el CSV de ventas.

    python3 supabase/scripts/sitec_kits_desde_csv.py --revisar ventas.csv > /tmp/sitec_kits_1_revisar.sql
    python3 supabase/scripts/sitec_kits_desde_csv.py ventas.csv > /tmp/sitec_kits_2_aplicar.sql

El CSV es la hoja «Registro» de registro_ventas_kits_sitec2026 exportada tal
cual: unas filas de título y después la cabecera (Folio, No. Control, Nombre
completo, ..., Tipo de Kit, ...). Se lee en UTF-8 o, si no, en Windows-1252,
que es como lo exporta Excel.

Los dos SQL se pegan en Supabase → SQL Editor, en ese orden. El de --revisar
no cambia nada: cuenta las ventas que casan con un asistente que ya está, lista
a quién se daría de alta y a los asistentes que no aparecen en ventas. El otro
crea la columna kit si falta, pone el kit a quien ya está y da de alta, con su
kit, a quien todavía no está (el token NFC se genera solo).

Cada asistente se busca por su nombre completo sin distinguir mayúsculas,
acentos ni espacios, así que se puede repetir con un CSV más reciente: no
duplica a nadie y no toca accesos ni tarjetas. Los nombres nuevos se limpian
igual que en la carga inicial: sin «Ing.» delante, con mayúscula inicial, y
las dos últimas palabras (con sus «de», «la»...) como apellidos.

El SQL lleva los nombres de los asistentes: genéralo fuera del repositorio.
El resumen (filas, kits, repetidos) sale por stderr para no mezclarse con él.
"""

from __future__ import annotations

import csv
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path

KITS = {'premium': 'premium', 'basico': 'basico', 'general': 'general'}
PARTICULAS = {'de', 'del', 'la', 'las', 'los'}
TITULO = re.compile(r'^(ing|inge|lic)\.\s*', re.IGNORECASE)

# Misma normalización que hace el SQL para comparar nombres: sin acentos, en
# minúsculas y con un solo espacio. translate() y no unaccent, que puede no
# estar instalada; y antes de lower(), que en un locale C no baja las tildes.
ACENTOS = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇáàäâéèëêíìïîóòöôúùüûñç'
SIN_ACENTOS = 'AAAAEEEEIIIIOOOOUUUUNCaaaaeeeeiiiioooouuuunc'
assert len(ACENTOS) == len(SIN_ACENTOS)


def leer_texto(ruta: Path) -> str:
    datos = ruta.read_bytes()
    try:
        return datos.decode('utf-8-sig')
    except UnicodeDecodeError:
        return datos.decode('cp1252')


def sin_acentos(texto: str) -> str:
    texto = unicodedata.normalize('NFKD', texto)
    return ''.join(c for c in texto if not unicodedata.combining(c))


def clave(nombre: str, apellidos: str | None) -> str:
    return ' '.join(sin_acentos(f'{nombre} {apellidos or ""}').lower().split())


def normalizar_kit(valor: str) -> str | None:
    return KITS.get(sin_acentos(valor).strip().lower())


def limpiar_nombre(completo: str) -> tuple[str, str | None]:
    palabras = TITULO.sub('', ' '.join(completo.split())).split()
    palabras = [
        p.lower() if i > 0 and p.lower() in PARTICULAS
        else p[:1].upper() + p[1:] if p.islower()
        else p
        for i, p in enumerate(palabras)
    ]
    if len(palabras) < 2:
        return ' '.join(palabras), None

    # Desde el final: dos apellidos y las partículas que los preceden, dejando
    # al menos una palabra para el nombre.
    inicio, apellidos = len(palabras), 0
    while inicio > 1 and apellidos < 2:
        inicio -= 1
        if palabras[inicio].lower() not in PARTICULAS:
            apellidos += 1
    while inicio > 1 and palabras[inicio - 1].lower() in PARTICULAS:
        inicio -= 1
    return ' '.join(palabras[:inicio]), ' '.join(palabras[inicio:])


def leer_ventas(texto: str) -> list[dict]:
    filas = list(csv.reader(texto.splitlines()))
    try:
        cabecera = next(i for i, f in enumerate(filas) if f and f[0].strip() == 'Folio')
    except StopIteration:
        sys.exit('No encuentro la fila de cabecera que empieza por «Folio».')
    columnas = [c.strip() for c in filas[cabecera]]
    try:
        i_folio = columnas.index('Folio')
        i_nombre = columnas.index('Nombre completo')
        i_kit = columnas.index('Tipo de Kit')
    except ValueError as faltante:
        sys.exit(f'Falta una columna en la cabecera: {faltante}')

    ventas = []
    for fila in filas[cabecera + 1:]:
        if len(fila) <= max(i_folio, i_nombre, i_kit) or not fila[i_nombre].strip():
            continue
        ventas.append({
            'folio': fila[i_folio].strip(),
            'nombre_completo': fila[i_nombre],
            'kit_csv': fila[i_kit],
        })
    return ventas


def literal(valor: str | None) -> str:
    return 'null' if valor is None else "'" + valor.replace("'", "''") + "'"


def sql_clave(nombre: str, apellidos: str) -> str:
    # normalize() junta la letra y su tilde si llegan separadas, y el espacio
    # duro (U+00A0) que a veces deja Excel cuenta como espacio.
    return (
        f"btrim(regexp_replace(lower(translate(normalize({nombre} || ' ' || "
        f"coalesce({apellidos}, ''), NFC), '{ACENTOS}', '{SIN_ACENTOS}')), "
        f"'[\\s\\u00a0]+', ' ', 'g'))"
    )


def sql_ventas(asistentes: list[tuple]) -> str:
    """Las ventas y los asistentes de la tabla, cada uno con su clave."""
    # El folio solo ordena; si no es un número, va como null.
    valores = ',\n'.join(
        f'    ({folio if folio.isdigit() else "null"}, {literal(nombre)}, '
        f'{literal(apellidos)}, {literal(kit)})'
        for folio, nombre, apellidos, kit in asistentes
    )
    return f"""with ventas (folio, nombre, apellidos, kit) as (
  values
{valores}
),
ventas_clave as (
  select v.*, {sql_clave('v.nombre', 'v.apellidos')} as clave
  from ventas v
),
tabla as (
  select a.id, a.nombre, a.apellidos, {sql_clave('a.nombre', 'a.apellidos')} as clave
  from public.sitec_asistentes a
)"""


def sql_revisar(asistentes: list[tuple], origen: str, resumen: str) -> str:
    return f"""-- SITEC: revisión antes de cargar los kits. Solo lectura: no cambia nada.
-- Generado con supabase/scripts/sitec_kits_desde_csv.py desde {origen}.
-- {resumen}.
--
-- Pégalo en Supabase → SQL Editor. Si «sin venta» está vacío, o solo tiene
-- pruebas, ejecuta después el SQL que aplica. Si alguien de «sin venta» está
-- también en «nuevos» escrito de otra forma, quedaría duplicado: corrígelo
-- antes de aplicar.
{sql_ventas(asistentes)}
select 'ya están: se les pone el kit' as grupo, count(*) as cuantos, null as quienes
from ventas_clave v
where exists (select 1 from tabla t where t.clave = v.clave)
union all
select 'nuevos: se dan de alta', count(*),
  string_agg(coalesce(v.folio || ' ', '') || btrim(v.nombre || ' ' || coalesce(v.apellidos, '')),
             ', ' order by v.folio)
from ventas_clave v
where not exists (select 1 from tabla t where t.clave = v.clave)
union all
select 'sin venta: se quedan sin kit', count(*),
  string_agg(btrim(t.nombre || ' ' || coalesce(t.apellidos, '')), ', '
             order by t.nombre, t.apellidos)
from tabla t
where not exists (select 1 from ventas_clave v where v.clave = t.clave);"""


def sql_aplicar(asistentes: list[tuple], origen: str, resumen: str) -> str:
    return f"""-- SITEC: kit de cada asistente según el registro de ventas.
-- Generado con supabase/scripts/sitec_kits_desde_csv.py desde {origen}.
-- {resumen}.
--
-- Pégalo entero en Supabase → SQL Editor, después del SQL de revisión. Se
-- puede repetir con un CSV más reciente: no duplica a nadie y no toca accesos
-- ni tarjetas.

-- 1. Columna kit. Es la migración 20261007220000_add_sitec_kit.sql; si ya
--    existe, no hace nada.
alter table public.sitec_asistentes
  add column if not exists kit text
    constraint sitec_asistentes_kit_check
    check (kit in ('premium', 'basico', 'general'));

-- 2. Kit para quien ya está y alta, con su kit, de quien falta. Es una sola
--    sentencia: si algo falla, no se aplica nada. Una venta sin kit no borra
--    el que ya tenga el asistente.
{sql_ventas(asistentes)},
con_kit as (
  update public.sitec_asistentes a
  set kit = v.kit
  from tabla t
  join ventas_clave v on v.clave = t.clave
  where a.id = t.id
    and v.kit is not null
    and a.kit is distinct from v.kit
  returning a.id
)
insert into public.sitec_asistentes (nombre, apellidos, kit)
select v.nombre, v.apellidos, v.kit
from ventas_clave v
where not exists (select 1 from tabla t where t.clave = v.clave)
order by v.folio;

-- 3. Resumen: cuántos asistentes hay de cada kit y quién quedó sin kit (no
--    está en el CSV de ventas).
select
  coalesce(kit, 'sin kit') as kit,
  count(*) as asistentes,
  string_agg(btrim(nombre || ' ' || coalesce(apellidos, '')), ', '
             order by nombre, apellidos) filter (where kit is null) as sin_kit
from public.sitec_asistentes
group by kit
order by kit nulls last;"""


def main() -> None:
    argumentos = sys.argv[1:]
    revisar = '--revisar' in argumentos
    rutas = [a for a in argumentos if a != '--revisar']
    if len(rutas) != 1:
        sys.exit(__doc__.split('\n\n')[1])
    ruta = Path(rutas[0])

    asistentes, vistos = [], {}
    for venta in leer_ventas(leer_texto(ruta)):
        nombre, apellidos = limpiar_nombre(venta['nombre_completo'])
        kit = normalizar_kit(venta['kit_csv'])
        if kit is None:
            print(f'Folio {venta["folio"]}: kit «{venta["kit_csv"].strip()}» desconocido, '
                  'se carga sin kit.', file=sys.stderr)
        k = clave(nombre, apellidos)
        if k in vistos:
            anterior = vistos[k]
            aviso = '' if anterior['kit'] == kit else f' ¡con otro kit ({kit})! Se queda {anterior["kit"]}'
            print(f'Folio {venta["folio"]}: {nombre} {apellidos or ""} repite el folio '
                  f'{anterior["folio"]}{aviso}; se omite.', file=sys.stderr)
            continue
        vistos[k] = {'folio': venta['folio'], 'kit': kit}
        asistentes.append((venta['folio'], nombre, apellidos, kit))

    if not asistentes:
        sys.exit('El CSV no tiene ninguna venta con nombre.')

    cuenta = Counter(kit for *_, kit in asistentes)
    resumen = (f'{len(asistentes)} asistentes: {cuenta["premium"]} Premium, '
               f'{cuenta["basico"]} Básico, {cuenta["general"]} General')
    if cuenta[None]:
        resumen += f', {cuenta[None]} sin kit'
    print(resumen + '.', file=sys.stderr)

    generar = sql_revisar if revisar else sql_aplicar
    print(generar(asistentes, ruta.name, resumen))


if __name__ == '__main__':
    main()
