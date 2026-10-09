# Staff App

Aplicación Flutter para el personal de eventos.

- Registro de equipo mediante QR y emisión individual de tarjetas NFC.
- Validación de accesos del hackathon: check-in y cena el viernes; desayuno, comida y check-out el sábado.
- Salidas del hackathon: la primera lectura en «Salida» marca a la persona fuera y la siguiente, de vuelta.
- Accesos de SITEC por día; el viernes, la comida con inicio y fin.
- Estados de interfaz simulados mientras se integran las APIs y el hardware NFC/QR.

## Ejecutar

```bash
flutter run
```

## iOS

La app de iOS solo necesita la firma con una cuenta de Apple Developer de pago. Los pasos para firmarla y subirla a TestFlight están en [ios/FIRMA.md](ios/FIRMA.md).

## iPhone sin la app

El staff con iPhone puede registrar accesos sin instalar la app: las tarjetas llevan una dirección que el iPhone abre en Safari, en la página de [lector-web/](lector-web/README.md). Para escribir las tarjetas así, la app se compila con `--dart-define=CARD_WEB_URL=<dirección de la página>`.

## Backend (Supabase Edge Functions)

Consulta la documentación detallada y comandos en [supabase/README.md](file:///Users/stringbuilder/staffapp/supabase/README.md).

- `staff-team-from-qr`: Búsqueda de equipos e integrantes vía QR sin exponer datos sensibles.
- `staff-issue-nfc`: Emisión y activación segura de tarjetas NFC (`staffapp:nfc:<token>`).
- `staff-scan-nfc`: Registro atómico de accesos con prevención de duplicados (409 Conflict).

