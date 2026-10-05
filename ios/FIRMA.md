# Firmar y publicar la app de iOS

El código y la configuración de iOS ya están en el repositorio, NFC incluido. Solo falta firmar la app con una cuenta de Apple Developer de pago (la gratuita no permite NFC) y subirla a TestFlight.

## Qué hace falta

- Una Mac con Xcode actualizado y Flutter 3.44 o posterior (el proyecto pide Dart 3.12).
- CocoaPods no hace falta: todos los plugins se instalan con Swift Package Manager. Si la compilación lo pide, es que Swift Package Manager está desactivado en tu Flutter; actívalo con:

  ```bash
  flutter config --enable-swift-package-manager
  ```
- Para probar el NFC, un iPhone 7 o posterior. El simulador no tiene NFC.

## Una sola vez

1. Clona el repositorio y, en la raíz, descarga las dependencias:

   ```bash
   flutter pub get
   ```

2. En Xcode → Settings → Accounts, pulsa "+" y entra con el Apple ID de la cuenta de pago.
3. Abre `ios/Runner.xcworkspace`, elige el target **Runner** y ve a la pestaña **Signing & Capabilities**:
   - Marca **Automatically manage signing** y elige tu **Team**.
   - La capacidad **Near Field Communication Tag Reading** ya aparece, porque viene en `Runner/Runner.entitlements`. No hay que añadirla: Xcode la activa en el identificador de la app al firmar.
   - El Bundle Identifier es `com.stringbuilder.staffapp.staffApp`. Si Xcode dice que no está disponible, cámbialo por uno tuyo, por ejemplo `com.tuorganizacion.staffapp`.
4. En [App Store Connect](https://appstoreconnect.apple.com) → Apps → "+" → **Nueva app**: plataforma iOS, un nombre, el idioma, el Bundle ID de la lista y un SKU interno cualquiera, por ejemplo `staffapp`.

## En cada versión

1. Genera el `.ipa` con un número de build mayor que el de la subida anterior (2, 3, 4…):

   ```bash
   flutter build ipa --build-number=2
   ```

   Flutter firma con tu Team y crea los perfiles que falten.
2. Sube el archivo de `build/ios/ipa/` con la app **Transporter** (gratis en la Mac App Store).
3. En la pestaña **TestFlight** de App Store Connect, cuando la build termine de procesarse:
   - **Testers externos**: un grupo con correos o un enlace público. La primera build pasa una revisión beta de Apple. Como la app pide iniciar sesión, en "Información de prueba" hay que dar una cuenta de staff de prueba para el revisor.
   - **Testers internos**: solo usuarios de tu equipo en App Store Connect. Instalan al momento, sin revisión.

Los testers instalan la app TestFlight en su iPhone y aceptan la invitación o abren el enlace. Cada build caduca a los 90 días.

## Probar en un iPhone sin pasar por TestFlight

1. Conecta el iPhone por cable y acepta "Confiar en este ordenador".
2. En iOS 16 o posterior, activa Ajustes → Privacidad y seguridad → **Modo de desarrollador**.
3. Lanza la app con el iPhone seleccionado. Usa `--release`: una build de depuración no se abre desde la pantalla de inicio sin el Mac conectado.

   ```bash
   flutter run --release
   ```

## Cómo lee el iPhone

- iOS muestra su propia hoja de lectura. En la pantalla de lectura se pulsa **Leer tarjeta NFC** para cada tarjeta, y la hoja se cierra sola a los 60 segundos. En Android el lector sigue armado todo el rato.
- La antena está en la parte de arriba del iPhone.
- Según la documentación de Apple, lee tarjetas NTAG213/215/216, MIFARE Ultralight e ISO 15693 con formato NDEF. **No lee MIFARE Classic**: iOS no lo admite. Con DESFire y otras de tipo 4 no está confirmado. Ninguna se ha probado aún en un iPhone real.
- Para escribir, la tarjeta tiene que venir ya con formato NDEF (las NTAG suelen venir así de fábrica). A diferencia de Android, iOS no da formato a tarjetas vírgenes.

## Si algo falla

- **La app dice "Esta versión de la app no tiene permiso de NFC"**: se firmó sin la capacidad NFC. Revisa Signing & Capabilities.
- **Error ITMS-90778 al subir ("NDEF is disallowed")**: el entitlement `com.apple.developer.nfc.readersession.formats` debe llevar solo `TAG`. Así viene en el repositorio; no lo cambies.
- **Xcode no deja registrar el Bundle Identifier**: ya lo usa otro equipo. Elige otro, como en el paso 3.
