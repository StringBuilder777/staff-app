import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Las clases de los mensajes del plugin no son públicas. Se usan para hacer de
// lado nativo de iOS, que es lo único que no corre en las pruebas. Al subir de
// versión nfc_manager hay que revisar estas pruebas y el tope de 65 segundos
// de NfcService, por si el plugin ya no pierde avisos.
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_ios/pigeon.g.dart';
import 'package:staff_app/config/backend_config.dart';
import 'package:staff_app/main.dart';
import 'package:staff_app/services/nfc_service.dart';

const _hostApi = 'dev.flutter.pigeon.nfc_manager.HostApiPigeon.';
const _flutterApi = 'dev.flutter.pigeon.nfc_manager.FlutterApiPigeon.';

/// Lado nativo de `nfc_manager` en iOS: responde a la app y le manda los
/// avisos de la hoja de lectura.
class _FakeIosNfc {
  _FakeIosNfc(this._tester);

  final WidgetTester _tester;

  /// Lo que responde `NFCTagReaderSession.readingAvailable`.
  bool readingAvailable = true;
  int availabilityChecks = 0;

  /// Argumentos de cada apertura de la hoja: opciones de sondeo, texto de la
  /// hoja y si deja de buscar tarjetas tras la primera detección.
  final begins = <List<Object?>>[];

  /// Argumentos de cada cierre pedido por la app: mensaje de éxito y de error.
  final invalidations = <List<Object?>>[];
  int writes = 0;

  /// Como en el plugin real, la sesión nativa solo se libera cuando la app la
  /// cierra, no cuando iOS cierra la hoja.
  bool _sessionOpen = false;

  void install() {
    final messenger = _tester.binding.defaultBinaryMessenger;
    // Pigeon responde `[valor]` si va bien y `[código, mensaje, detalles]` si
    // falla.
    void answer(String method, List<Object?> Function(List<Object?> args) reply) {
      messenger.setMockMessageHandler('$_hostApi$method', (message) async {
        final args =
            HostApiPigeon.pigeonChannelCodec.decodeMessage(message)
                as List<Object?>? ??
            const [];
        return HostApiPigeon.pigeonChannelCodec.encodeMessage(reply(args));
      });
      addTearDown(
        () => messenger.setMockMessageHandler('$_hostApi$method', null),
      );
    }

    answer('tagSessionReadingAvailable', (_) {
      availabilityChecks++;
      return [readingAvailable];
    });
    answer('tagSessionBegin', (args) {
      if (_sessionOpen) return ['session_already_exists', null, null];
      _sessionOpen = true;
      begins.add(args);
      return [null];
    });
    answer('tagSessionInvalidate', (args) {
      if (!_sessionOpen) return ['no_active_sessions', null, null];
      _sessionOpen = false;
      invalidations.add(args);
      return [null];
    });
    answer('ndefWriteNdef', (_) {
      writes++;
      return [null];
    });
  }

  /// La hoja detecta una tarjeta.
  Future<void> detect(TagPigeon card) => _send('tagSessionDidDetect', card);

  /// iOS cierra la hoja por su cuenta. La sesión nativa sigue abierta.
  Future<void> close(NfcReaderErrorCodePigeon code) => _send(
    'tagSessionDidInvalidateWithError',
    NfcReaderSessionErrorPigeon(code: code, message: code.name),
  );

  Future<void> _send(String method, Object argument) =>
      _tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        '$_flutterApi$method',
        FlutterApiPigeon.pigeonChannelCodec.encodeMessage(<Object?>[argument]),
        (_) {},
      );
}

/// Tarjeta con NDEF. Con [text] trae además un registro de texto como los que
/// escribe la app.
TagPigeon _card({
  NdefStatusPigeon status = NdefStatusPigeon.readWrite,
  int capacity = 137,
  String? text,
}) => TagPigeon(
  handle: 'tarjeta-1',
  ndef: NdefPigeon(
    status: status,
    capacity: capacity,
    cachedNdefMessage: text == null
        ? null
        : NdefMessagePigeon(
            records: [
              NdefPayloadPigeon(
                typeNameFormat: TypeNameFormatPigeon.wellKnown,
                type: Uint8List.fromList([0x54]),
                identifier: Uint8List(0),
                payload: Uint8List.fromList([
                  2,
                  ...ascii.encode('en'),
                  ...utf8.encode(text),
                ]),
              ),
            ],
          ),
  ),
);

/// Prepara un iPhone simulado y abre el punto de CHECK-IN con el lector real.
Future<_FakeIosNfc> _openCheckIn(
  WidgetTester tester, {
  bool readingAvailable = true,
}) async {
  // Pantalla de un iPhone 17. En el lienzo por defecto de las pruebas
  // (800 × 600) la pantalla de lectura no cabe.
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Túnel no exige login y, a diferencia de simulación, usa el lector real.
  BackendConfig.mode = BackendMode.tunnel;
  addTearDown(() => BackendConfig.mode = BackendMode.simulation);

  final nfc = _FakeIosNfc(tester)
    ..readingAvailable = readingAvailable
    ..install();

  await tester.pumpWidget(const StaffApp());
  await tester.tap(find.text('HACKATHON'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('EVENTOS'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CHECK-IN'));
  await tester.pumpAndSettle();
  return nfc;
}

/// PrimaryAction pinta las etiquetas en versales.
final _readButton = find.text('LEER TARJETA NFC');

final _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  testWidgets('on iOS the reader opens only when the operator asks', (
    tester,
  ) async {
    final nfc = await _openCheckIn(tester, readingAvailable: false);

    // Armar el lector al entrar abriría la hoja del sistema sin pedirla.
    expect(nfc.availabilityChecks, 0);
    expect(find.text('LISTO PARA\nLEER'), findsOneWidget);

    // La hoja de lectura deja la app inactiva y al cerrarse la reanuda:
    // rearmar ahí la reabriría sin fin.
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(nfc.availabilityChecks, 0);

    await tester.tap(_readButton);
    await tester.pumpAndSettle();

    // Una sola comprobación, y la pantalla explica por qué no lee.
    expect(nfc.availabilityChecks, 1);
    expect(nfc.begins, isEmpty);
    expect(find.text('NFC NO\nDISPONIBLE'), findsOneWidget);
    expect(find.text('Este teléfono no tiene NFC.'), findsWidgets);
  }, variant: _iOS);

  testWidgets('on iOS a read closes the sheet and does not reopen it', (
    tester,
  ) async {
    final nfc = await _openCheckIn(tester);

    await tester.tap(_readButton);
    await tester.pump();

    final [polling, prompt, invalidateAfterFirstRead] = nfc.begins.single;
    // FeliCa queda fuera: sin sus códigos en Info.plist la sesión falla.
    expect(polling, [
      PollingOptionPigeon.iso14443,
      PollingOptionPigeon.iso15693,
    ]);
    expect(prompt, 'Acerca la tarjeta a la parte de arriba del iPhone.');
    // La lectura sigue buscando si una detección falla a medias.
    expect(invalidateAfterFirstRead, isFalse);

    await nfc.detect(_card(text: 'staffapp:nfc:abc123'));
    await tester.pumpAndSettle();

    // La hoja se cierra con el mensaje de éxito y la credencial llega a la
    // pantalla. Lo que conteste el backend no importa aquí.
    expect(nfc.invalidations, [
      ['Tarjeta leída', null],
    ]);
    expect(find.text('staffapp:nfc:abc123'), findsOneWidget);
    expect(nfc.begins, hasLength(1));
  }, variant: _iOS);

  testWidgets('on iOS cancelling the sheet is not an error', (tester) async {
    final nfc = await _openCheckIn(tester);

    await tester.tap(_readButton);
    await tester.pump();
    await nfc.close(
      NfcReaderErrorCodePigeon.readerSessionInvalidationErrorUserCanceled,
    );
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('LISTO PARA\nLEER'), findsOneWidget);
    // La sesión nativa se libera igual, sin mensaje en la hoja.
    expect(nfc.invalidations, [
      [null, null],
    ]);
    expect(nfc.begins, hasLength(1));
  }, variant: _iOS);

  testWidgets('on iOS the sheet opens again after it times out', (
    tester,
  ) async {
    final nfc = await _openCheckIn(tester);
    const noCard = 'No se detectó ninguna tarjeta a tiempo. Inténtalo de nuevo.';

    await tester.tap(_readButton);
    await tester.pump();
    await nfc.close(
      NfcReaderErrorCodePigeon.readerSessionInvalidationErrorSessionTimeout,
    );
    await tester.pumpAndSettle();

    expect(find.text(noCard), findsOneWidget);
    // Cerrar la sesión nativa es lo que deja abrir la siguiente: sin eso el
    // plugin responde `session_already_exists`.
    expect(nfc.invalidations, [
      [null, noCard],
    ]);

    // Se espera a que se vaya el aviso, que tapa el botón.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(_readButton);
    await tester.pump();
    expect(nfc.begins, hasLength(2));

    await nfc.close(
      NfcReaderErrorCodePigeon.readerSessionInvalidationErrorUserCanceled,
    );
    await tester.pumpAndSettle();
  }, variant: _iOS);

  testWidgets('on iOS writing refuses cards it cannot write', (tester) async {
    final nfc = _FakeIosNfc(tester)..install();

    Future<NfcOperationResult> writeOn(TagPigeon card) async {
      final result = const NfcService().writeTextPayload('staffapp:nfc:abc');
      await tester.pump();
      await nfc.detect(card);
      return result;
    }

    final readOnly = await writeOn(_card(status: NdefStatusPigeon.readOnly));
    expect(
      readOnly.errorMessage,
      'La tarjeta está protegida contra escritura.',
    );
    // iOS no da formato NDEF a tarjetas vírgenes.
    final blank = await writeOn(_card(status: NdefStatusPigeon.notSupported));
    expect(blank.errorMessage, 'La tarjeta no es compatible con NDEF.');
    final small = await writeOn(_card(capacity: 10));
    expect(small.errorMessage, contains('solo admite 10'));
    expect(nfc.writes, 0);

    final written = await writeOn(_card());
    expect(written.success, isTrue);
    expect(nfc.writes, 1);

    // El error queda escrito en la hoja al cerrarla, y también el éxito.
    expect(nfc.invalidations.first, [
      null,
      'La tarjeta está protegida contra escritura.',
    ]);
    expect(nfc.invalidations.last, ['Tarjeta escrita', null]);
    // La escritura deja de buscar tras detectar: necesita la tarjeta
    // conectada hasta escribirla.
    expect(nfc.begins.map((args) => args[2]), everyElement(isTrue));
  }, variant: _iOS);

  testWidgets('on iOS a build signed without NFC says so', (tester) async {
    final nfc = await _openCheckIn(tester);

    await tester.tap(_readButton);
    await tester.pump();
    // Es lo que responde iOS si la app se firmó sin la capacidad NFC.
    await nfc.close(NfcReaderErrorCodePigeon.readerErrorSecurityViolation);
    await tester.pumpAndSettle();

    expect(find.text('NFC NO\nDISPONIBLE'), findsOneWidget);
    expect(
      find.text(
        'Esta versión de la app no tiene permiso de NFC. Revisa la firma en '
        'Xcode.',
      ),
      findsWidgets,
    );
  }, variant: _iOS);

  // Va la última: si falla, deja una sesión abierta en el estado estático del
  // servicio y la prueba siguiente se quedaría esperando a que se cierre.
  testWidgets('on iOS a lost close notice does not leave the screen waiting', (
    tester,
  ) async {
    final nfc = await _openCheckIn(tester);

    await tester.tap(_readButton);
    await tester.pump();
    expect(find.text('ESPERANDO\nTARJETA'), findsOneWidget);

    // Con los códigos de iOS 26 el plugin pierde el aviso de cierre. La
    // pantalla pide 10 minutos de espera, pero en iOS se corta antes. Se mira
    // justo después: esperar a que la pantalla se asiente dejaría pasar
    // también los 10 minutos.
    await tester.pump(const Duration(seconds: 66));
    await tester.pump();

    expect(find.text('ESPERANDO\nTARJETA'), findsNothing);
    expect(nfc.invalidations, hasLength(1));
    await tester.pumpAndSettle();
  }, variant: _iOS);
}
