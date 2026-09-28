# Staff App — Nothing Inspired

## 00. Alcance y adaptación

El documento original describía un **sitio web de registro a un evento**: hero,
ponentes, agenda, FAQ, formulario de inscripción y ticket QR.

Esta app es otra cosa: una **herramienta de operación para staff** que escanea
QR de equipo, escribe credenciales NFC y valida accesos en la puerta. No tiene
landing, ni ponentes, ni agenda.

Se conservan los **principios**. Se descartan las secciones que describen
estructura de sitio web.

| Del documento original | Estado |
|---|---|
| Colores, tipografía, jerarquía, layout | Aplica |
| Botones, inputs, lenguaje gráfico, números grandes | Aplica |
| Animación, estilo prohibido, reglas de agente | Aplica |
| Hero, agenda, ponentes, fotografía, ticket QR, FAQ | No aplica aquí |

Contexto de uso que manda sobre cualquier decisión estética: **se opera de pie,
con prisa, con una mano, en un pasillo con gente esperando.** Si una decisión
visual compite con leer una tarjeta rápido, gana leer rápido.

---

## 01. Personalidad

ROTUNDO · MÍNIMO · TÉCNICO · EDITORIAL · PRECISO

La pantalla debe parecer un instrumento, no un panel de administración.

---

## 02. Color

Claro:

```
Fondo      #F3F3F1
Negro      #111111
Blanco     #FFFFFF
Apagado    #8A8A86
Borde      #CBCBC6
Acento     #E53935
```

Oscuro:

```
Fondo      #090909
Superficie #111111
Texto      #F4F4F2
Apagado    #888888
Borde      #292929
Acento     #E53935
```

El rojo es deliberado, no decorativo. Se reserva para:

- estado denegado o duplicado
- sin conexión
- acción destructiva
- el marcador de evento activo

**Nunca** teñir la interfaz de rojo. En esta app hay un uso más: el verde de
conexión y el ámbar de duplicado son semáforos operativos y se mantienen,
porque comunican estado y no marca.

---

## 03. Tipografía

Ideal: **Geist** y **Geist Mono**.

Estado actual: no están empaquetadas. Se usa la familia del sistema con
tratamiento agresivo, y `monospace` (Roboto Mono en Android) para metadatos.
Añadir Geist es cuestión de meter los `.ttf` en `fonts/` y declararlos en
`pubspec.yaml`.

Jerarquía:

```
Etiqueta técnica   11–12 px · mayúsculas · tracking .08em · apagado
Display            32–64 px · peso 800 · line-height .92
Título de sección  20–24 px · peso 700
Cuerpo             15–16 px
Metadato           13 px · monoespaciada
```

Los títulos van apretados. El aire se pone alrededor, no dentro.

---

## 04. Layout

Editorial, no apilado de tarjetas.

- Tipografía grande y espacio vacío antes que decoración
- Separadores de 1 px antes que sombras
- Alineación a rejilla estricta
- Márgenes móviles: 20–24 px

**Una tarjeta solo cuando agrupa datos de una persona.** Todo lo demás —listas,
metadatos, estados— va sobre el fondo con separadores.

---

## 05. Números como elemento gráfico

Los números son identidad visual, no adorno.

```
02        08         409
EVENTOS   EQUIPOS    DUPLICADO
```

Cifra enorme, etiqueta minúscula debajo en mayúsculas.

---

## 06. Lenguaje gráfico

Elementos geométricos simples: `○ ● + × → /`

El punto de conexión ya sigue esto. Un círculo grande vale como marcador de
evento o de estado.

---

## 07. Botones

- Primario: fondo negro, texto blanco, esquinas mínimas
- Secundario: borde de 1 px, fondo transparente
- Destructivo: fondo acento

Prohibido: degradados, sombras, resplandores, esquinas muy redondeadas.

Altura mínima 56 px: se pulsa de pie y con prisa.

---

## 08. Inputs

Sin caja. Borde inferior de 1 px, fondo transparente, padding vertical de
16 px. Etiqueta pequeña en mayúsculas encima. Al enfocar, el borde pasa a negro.

---

## 09. Animación

Sutil y corta, 200–400 ms. Revelado de texto, expansión de línea, cambio de
estado, transición numérica.

Prohibido: parallax, blobs flotantes, 3D, texto con resplandor, confeti.

---

## 10. Estilo prohibido

No debe parecer: panel SaaS, admin, plantilla Bootstrap, web de cripto.

Evitar: glassmorphism, degradados, sombras grandes, exceso de tarjetas, paletas
azul/morado por defecto, todo redondeado.

---

## 11. Reglas para agentes

1. Leer este archivo antes de tocar la interfaz.
2. Reutilizar lo que hay en `lib/theme/nothing.dart`. No inventar colores.
3. Tipografía antes que decoración. Bordes antes que sombras.
4. No añadir tarjetas innecesarias.
5. Móvil es el único cliente real: primera clase siempre.
6. **La accesibilidad manda sobre el experimento visual.** Un punto de color
   nunca es el único portador de información: acompañarlo de texto o etiqueta
   semántica.
7. **El contraste no se negocia.** El apagado `#8A8A86` sobre fondo `#F3F3F1`
   no llega a AA para texto pequeño: usarlo solo en 13 px o mayor, y nunca para
   información crítica.
8. No copiar una pantalla de Nothing tal cual. Crear identidad propia con estos
   principios.
