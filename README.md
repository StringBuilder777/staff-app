# Staff App

Herramientas para el personal de eventos. En Android se usa la app Flutter y en iPhone se registran accesos desde Safari.

- Registro de equipo mediante QR y emisión individual de tarjetas NFC.
- Validación de accesos del hackathon: check-in y cena el viernes; desayuno, comida y check-out el sábado.
- Salidas del hackathon: la primera lectura en «Salida» marca a la persona fuera y la siguiente, de vuelta.
- Accesos de SITEC por día; el viernes, la comida con inicio y fin.
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

Para emitir tarjetas compatibles, compila la app que las graba con `--dart-define=CARD_WEB_URL=<URL del lector>`. Consulta las [instrucciones para publicar y configurar el lector web](lector-web/README.md).

## Backend (Supabase Edge Functions)

Consulta la documentación detallada y comandos en [supabase/README.md](file:///Users/stringbuilder/staffapp/supabase/README.md).

- `staff-team-from-qr`: Búsqueda de equipos e integrantes vía QR sin exponer datos sensibles.
- `staff-issue-nfc`: Emisión y activación segura de tarjetas NFC (`staffapp:nfc:<token>`).
- `staff-scan-nfc`: Registro atómico de accesos con prevención de duplicados (409 Conflict).

