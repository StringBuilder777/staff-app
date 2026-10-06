# Lector web para iPhone

Página para que el staff con iPhone registre accesos sin la app. Un iPhone (XS
o posterior) lee por su cuenta las tarjetas que llevan una dirección: al
acercar una sale el aviso «Abrir en Safari», y esta página registra el acceso
en el punto elegido con las mismas Edge Functions y la misma cuenta de staff
que la app.

Una página no puede leer NFC en iPhone porque Safari no implementa Web NFC. Por
eso la dirección va grabada en la tarjeta y es el propio iPhone quien la lee.

## Publicarla

Es una carpeta estática, sin dependencias ni paso de compilación. En Netlify,
entra en <https://app.netlify.com/drop> y arrastra la carpeta `lector-web/`.
Después, en Site configuration → Change site name, ponle un nombre corto. En
Vercel o Cloudflare Pages es igual: se publica la carpeta tal cual.

La dirección queda grabada en cada tarjeta, así que tiene que ser corta. En una
NTAG213 caben como mucho 38 caracteres entre dominio y ruta
(`staff-sitec.netlify.app` usa 23). Si es más larga, la app no la usa y escribe
las tarjetas como antes, solo con texto, que no se abren en iPhone.

## Activarla en la app

Las tarjetas solo llevan la dirección si la app se compila con ella:

```bash
flutter build apk --release --dart-define=CARD_WEB_URL=https://staff-sitec.netlify.app
```

Sin `CARD_WEB_URL` la app escribe las tarjetas como siempre.

Esta versión de la app lee las tarjetas con dirección y también las de antes.
Las versiones anteriores no leen las que llevan dirección: antes de escribir
tarjetas así, actualiza todos los teléfonos que leen, tanto los Android como
los iPhone con la app.

Conviene fijar la dirección antes de escribir las tarjetas de verdad: cada
tarjeta abre siempre la que lleva grabada.

Con dirección, la tarjeta lleva primero la dirección, que es lo que mira el
iPhone, y después un registro de aplicación de Android (AAR). Con él, un
Android con la app instalada abre la app en vez del navegador y el operador no
sale de ella. Un Android sin la app abre la ficha de la app en Google Play.

## Usarla en el iPhone

1. Abre la página en Safari, entra con tu cuenta de staff y elige el punto.
2. Con la pantalla desbloqueada, acerca la tarjeta a la parte de arriba del
   iPhone.
3. Toca el aviso «Abrir en Safari». La página registra el acceso y muestra a
   quién pertenece la tarjeta.

Si falla la red o el servidor, la tarjeta queda en «Sin registrar» y se
reintenta a mano, siempre en el punto donde se leyó. Esa lista es de la
pestaña: si se cierra o se recarga, vuelve a acercar la tarjeta. Una tarjeta
que espera a que entres o elijas el punto caduca a los cinco minutos.

No la añadas a la pantalla de inicio: el aviso abre la tarjeta en Safari, que
tiene su propia sesión. El iPhone no lee tarjetas mientras se usa la cámara o
Wallet, ni en modo avión. Un iPhone con la app instalada también muestra el
aviso entre lecturas; vale cualquiera de las dos.

## Probarla en el Mac

```bash
python3 -m http.server 8080 --directory lector-web
```

Después abre `http://localhost:8080/#s/<token>`. Con una sesión de staff y un
token real, el acceso se registra de verdad en Supabase.

## Seguridad

- El token va tras `#`: el navegador no lo manda al servidor que publica la
  página, solo a Supabase.
- La página no carga código de terceros: pide la sesión directamente a
  Supabase Auth, y `index.html` limita con CSP el código a esta carpeta y las
  conexiones al proyecto de Supabase.
- La clave anon de `config.js` es la misma clave pública que va dentro del
  APK. Para registrar hace falta una sesión de staff con permiso, igual que en
  la app. Salir cierra solo la sesión de ese teléfono.
- Mantén el sitio publicado mientras haya tarjetas en uso. Si se borra y otra
  persona se queda con el nombre, las tarjetas abrirían su página, con el
  token, y podría pedir credenciales de staff. Con un dominio propio no pasa.
