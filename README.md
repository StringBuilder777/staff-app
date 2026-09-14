# Staff App

Aplicación Flutter para el personal de eventos.

- Registro de equipo mediante QR y emisión individual de tarjetas NFC.
- Validación de accesos para check-in, desayuno y comida.
- Estados de interfaz simulados mientras se integran las APIs y el hardware NFC/QR.

## Ejecutar

```bash
flutter run
```

## Backend (Supabase Edge Functions)

Consulta la documentación detallada y comandos en [supabase/README.md](file:///Users/stringbuilder/staffapp/supabase/README.md).

- `staff-team-from-qr`: Búsqueda de equipos e integrantes vía QR sin exponer datos sensibles.
- `staff-issue-nfc`: Emisión y activación segura de tarjetas NFC (`staffapp:nfc:<token>`).
- `staff-scan-nfc`: Registro atómico de accesos con prevención de duplicados (409 Conflict).

