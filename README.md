# Staff App

Herramientas para el personal de eventos. En Android se usa la app Flutter y en iPhone se registran accesos desde Safari.

- Registro de equipo mediante QR y emisión individual de tarjetas NFC.
- Validación de accesos para check-in, desayuno y comida.
- Estados de interfaz simulados mientras se integran las APIs y el hardware NFC/QR.

## Ejecutar la app en Android

```bash
flutter run
```

## Registrar accesos en iPhone

En iPhone, el flujo de registro de accesos se realiza en Safari sin instalar una app nativa. La tarjeta NFC debe llevar grabado el enlace HTTPS del lector web.

1. Abre el lector web en Safari, inicia sesión con tu cuenta de staff y elige el evento y el punto de acceso.
2. Con el iPhone desbloqueado, acerca la tarjeta NFC a la parte superior del teléfono.
3. Toca «Abrir en Safari» y confirma en pantalla que se registró el acceso.

La implementación del lector web y las instrucciones para publicarlo están en `lector-web/README.md` de la rama `feat/iphone-web`. Para emitir tarjetas compatibles, la versión de la app que las graba se compila con `--dart-define=CARD_WEB_URL=<URL del lector>`.

## Backend (Supabase Edge Functions)

Consulta la documentación detallada y comandos en [supabase/README.md](file:///Users/stringbuilder/staffapp/supabase/README.md).

- `staff-team-from-qr`: Búsqueda de equipos e integrantes vía QR sin exponer datos sensibles.
- `staff-issue-nfc`: Emisión y activación segura de tarjetas NFC (`staffapp:nfc:<token>`).
- `staff-scan-nfc`: Registro atómico de accesos con prevención de duplicados (409 Conflict).

