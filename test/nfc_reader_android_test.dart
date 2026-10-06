import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// Las clases de los mensajes del plugin no son públicas. Se usan para hacer de
// lado nativo de Android, igual que en nfc_reader_ios_test.dart.
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_android/pigeon.g.dart';
import 'package:staff_app/config/backend_config.dart';
import 'package:staff_app/main.dart';
import 'package:staff_app/services/nfc_service.dart';

const _hostApi = 'dev.flutter.pigeon.nfc_manager.HostApiPigeon.';

const _token = '0f8fad5b-d9cb-469f-a165-70867728950e';
const _payload = 'staffapp:nfc:$_token';

/// Responde por el lado nativo de `nfc_manager` en Android. La respuesta es la
/// lista que manda Pigeon: `[valor]` si va bien y `[código, mensaje, detalles]`
/// si falla.
void _answer(
  WidgetTester tester,
  String method,
  FutureOr<List<Object?>> Function() reply,
) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMessageHandler(
    '$_hostApi$method',
    (_) async => HostApiPigeon.pigeonChannelCodec.encodeMessage(await reply()),
  );
  addTearDown(() => messenger.setMockMessageHandler('$_hostApi$method', null));
}

/// Tarjeta con estructura NDEF y [maxSize] bytes libres, como una NTAG213.
TagPigeon _ndefCard({int maxSize = 137}) => TagPigeon(
  handle: 'tarjeta-1',
  id: Uint8List.fromList([1, 2, 3, 4]),
  techList: const ['android.nfc.tech.Ndef'],
  ndef: NdefPigeon(
    type: 'org.nfcforum.ndef.type2',
    canMakeReadOnly: true,
    isWritable: true,
    maxSize: maxSize,
  ),
);

/// El lector de Android detecta [card].
Future<void> _discover(WidgetTester tester, TagPigeon card) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'dev.flutter.pigeon.nfc_manager.FlutterApiPigeon.onTagDiscovered',
      FlutterApiPigeon.pigeonChannelCodec.encodeMessage(<Object?>[card]),
      (_) {},
    );

/// Mensajes que la app escribe en las tarjetas con [method]:
/// `ndefWriteNdefMessage`, o `ndefFormatableFormat` en las vírgenes.
List<NdefMessagePigeon> _recordWrites(
  WidgetTester tester, {
  String method = 'ndefWriteNdefMessage',
}) {
  final written = <NdefMessagePigeon>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  final channel = '$_hostApi$method';
  messenger.setMockMessageHandler(channel, (message) async {
    final args =
        HostApiPigeon.pigeonChannelCodec.decodeMessage(message)!
            as List<Object?>;
    written.add(args[1]! as NdefMessagePigeon);
    return HostApiPigeon.pigeonChannelCodec.encodeMessage(<Object?>[null]);
  });
  addTearDown(() => messenger.setMockMessageHandler(channel, null));
  return written;
}

/// Lector de un teléfono con el NFC encendido. Devuelve lo que le va pidiendo
/// la app: `check` al comprobar el NFC, `arm` al abrir el lector y `disarm` al
/// cerrarlo. Con [check] y [disarm] esas respuestas esperan a que se completen.
List<String> _recordReader(
  WidgetTester tester, {
  Future<void>? check,
  Future<void>? disarm,
}) {
  final calls = <String>[];
  _answer(tester, 'nfcAdapterIsEnabled', () async {
    calls.add('check');
    if (check != null) await check;
    return [true];
  });
  _answer(tester, 'nfcAdapterEnableReaderMode', () {
    calls.add('arm');
    return [null];
  });
  _answer(tester, 'nfcAdapterDisableReaderMode', () async {
    calls.add('disarm');
    if (disarm != null) await disarm;
    return [null];
  });
  return calls;
}

/// Abre el punto de CHECK-IN con el lector real en un teléfono Android.
Future<void> _openCheckIn(WidgetTester tester) async {
  // Pantalla de un Pixel 8. En el lienzo por defecto de las pruebas
  // (800 × 600) la pantalla de lectura no cabe.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  // Túnel no exige login y, a diferencia de simulación, usa el lector real.
  BackendConfig.mode = BackendMode.tunnel;
  addTearDown(() => BackendConfig.mode = BackendMode.simulation);

  await tester.pumpWidget(const StaffApp());
  await tester.tap(find.text('HACKATHON'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('EVENTOS'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CHECK-IN'));
}

void main() {
  testWidgets('scan screen stops retrying while NFC is turned off', (
    tester,
  ) async {
    var checks = 0;
    _answer(tester, 'nfcAdapterIsEnabled', () {
      checks++;
      return [false];
    });

    await _openCheckIn(tester);
    // Antes el lector se rearmaba sin pausa y repetía el aviso sin fin, así
    // que la pantalla nunca llegaba a asentarse.
    await tester.pumpAndSettle();

    expect(checks, 1);
    expect(find.text('NFC NO\nDISPONIBLE'), findsOneWidget);
    expect(
      find.text(
        'El NFC está desactivado. Actívalo en los ajustes del teléfono.',
      ),
      findsWidgets,
    );

    // Al volver de los ajustes del teléfono lo intenta una vez más. Va la
    // secuencia completa porque el framework rechaza saltarse estados.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(checks, 2);
  });

  testWidgets('scan screen rearms the reader after an ordinary failure', (
    tester,
  ) async {
    var arms = 0;
    _answer(tester, 'nfcAdapterIsEnabled', () => [true]);
    // El primer intento de armar el lector falla; los siguientes funcionan.
    _answer(
      tester,
      'nfcAdapterEnableReaderMode',
      () => ++arms == 1 ? ['error', 'No se pudo armar', null] : [null],
    );
    _answer(tester, 'nfcAdapterDisableReaderMode', () => [null]);

    await _openCheckIn(tester);
    // La espera de tarjeta anima en bucle, así que no se puede esperar a que
    // la pantalla se asiente.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Un fallo cualquiera no es «sin NFC»: en Android el lector vuelve a
    // armarse solo, porque cerrado devolvería la tarjeta al sistema.
    expect(arms, 2);
    expect(find.text('ESPERANDO\nTARJETA'), findsOneWidget);

    // Al salir se cierra el lector y no queda nada pendiente.
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  // El teléfono tarda un momento en contestar si hay NFC. Si en ese rato se
  // cierra la hoja que pidió la escritura, su cancel() no encontraba sesión que
  // cerrar: el lector se abría igual y la siguiente tarjeta que se acercara se
  // escribía con la credencial de esa hoja.
  testWidgets('cancel stops an operation that is still checking NFC', (
    tester,
  ) async {
    final check = Completer<void>();
    final calls = _recordReader(tester, check: check.future);

    NfcOperationResult? result;
    unawaited(
      const NfcService()
          .writeTextPayload('staffapp:nfc:abc')
          .then((value) => result = value),
    );
    await tester.pump();
    await const NfcService().cancel();
    check.complete();
    // Pasa el tiempo de espera entero: si el lector llegara a abrirse, se
    // cierra solo antes de comprobar nada y no queda abierto para las pruebas
    // siguientes.
    await tester.pump(NfcService.defaultTimeout);

    expect(result?.cancelled, isTrue);
    // El lector no llega a abrirse.
    expect(calls, ['check']);
  });

  testWidgets('cancel stops an operation that waits for the last one to close', (
    tester,
  ) async {
    final disarm = Completer<void>();
    final calls = _recordReader(tester, disarm: disarm.future);

    final read = const NfcService().readTextPayload();
    await tester.pump();
    NfcOperationResult? write;
    unawaited(
      const NfcService()
          .writeTextPayload('staffapp:nfc:abc')
          .then((value) => write = value),
    );
    await tester.pump();
    // La escritura cerró la lectura y espera a que el lector quede libre.
    expect(calls, ['check', 'arm', 'check', 'disarm']);

    final cancelling = const NfcService().cancel();
    disarm.complete();
    await cancelling;
    // Como en la prueba anterior.
    await tester.pump(NfcService.defaultTimeout);

    expect((await read).cancelled, isTrue);
    expect(write?.cancelled, isTrue);
    expect(calls, ['check', 'arm', 'check', 'disarm']);
  });

  testWidgets('a new operation closes the last one and still opens the reader', (
    tester,
  ) async {
    final calls = _recordReader(tester);

    NfcOperationResult? first;
    unawaited(
      const NfcService().readTextPayload().then((value) => first = value),
    );
    await tester.pump();
    NfcOperationResult? second;
    unawaited(
      const NfcService().readTextPayload().then((value) => second = value),
    );
    await tester.pump();

    // Cerrar la operación anterior no cancela la nueva.
    expect(first?.cancelled, isTrue);
    expect(second, isNull);
    expect(calls, ['check', 'arm', 'check', 'disarm', 'arm']);

    await const NfcService().cancel();
    await tester.pump();
    expect(second?.cancelled, isTrue);
    expect(calls.last, 'disarm');
  });

  testWidgets('cards with the web address stay with the app on Android', (
    tester,
  ) async {
    _recordReader(tester);
    final written = _recordWrites(tester);

    Future<NfcOperationResult> writeOn(TagPigeon card) async {
      final result = const NfcService().writeTextPayload(
        _payload,
        webUrl: 'https://staff.test/#s/$_token',
      );
      await tester.pump();
      await _discover(tester, card);
      return result;
    }

    expect((await writeOn(_ndefCard())).success, isTrue);
    final records = written.last.records;
    // Primero la dirección, que es lo único que mira un iPhone sin la app.
    expect(records.first.tnf, TypeNameFormatPigeon.wellKnown);
    expect(records.first.type, [0x55]);
    expect(records.first.payload, [
      0x04,
      ...utf8.encode('staff.test/#s/$_token'),
    ]);
    // Detrás el AAR: Android da la tarjeta a la app y no al navegador.
    expect(records.last.tnf, TypeNameFormatPigeon.external);
    expect(utf8.decode(records.last.type), 'android.com:pkg');
    expect(
      utf8.decode(records.last.payload),
      'com.stringbuilder.staffapp.staff_app',
    );

    // Esta dirección ocupa 109 bytes: justo cabe.
    expect((await writeOn(_ndefCard(maxSize: 109))).success, isTrue);
    expect(written.last.records.first.type, [0x55]);

    // Donde no cabe la dirección va solo el texto, que la app sigue leyendo.
    expect((await writeOn(_ndefCard(maxSize: 108))).success, isTrue);
    expect(written.last.records.single.type, [0x54]);
  });

  testWidgets('blank cards on Android are formatted with the web address', (
    tester,
  ) async {
    _recordReader(tester);
    final formatted = _recordWrites(tester, method: 'ndefFormatableFormat');

    final result = const NfcService().writeTextPayload(
      _payload,
      webUrl: 'https://staff.test/#s/$_token',
    );
    await tester.pump();
    await _discover(
      tester,
      TagPigeon(
        handle: 'tarjeta-1',
        id: Uint8List.fromList([1, 2, 3, 4]),
        techList: const ['android.nfc.tech.NdefFormatable'],
        ndefFormatable: 'android.nfc.tech.NdefFormatable',
      ),
    );

    expect((await result).success, isTrue);
    expect(formatted.single.records.first.type, [0x55]);
  });

  testWidgets('the app reads the credential from a card with the address', (
    tester,
  ) async {
    _recordReader(tester);
    _answer(
      tester,
      'ndefGetNdefMessage',
      () => [
        NdefMessagePigeon(
          records: [
            NdefRecordPigeon(
              tnf: TypeNameFormatPigeon.wellKnown,
              type: Uint8List.fromList([0x55]),
              id: Uint8List(0),
              payload: Uint8List.fromList([
                0x04,
                ...utf8.encode('otra.test/#s/$_token'),
              ]),
            ),
          ],
        ),
      ],
    );

    final read = const NfcService().readTextPayload();
    await tester.pump();
    await _discover(tester, _ndefCard());

    // La credencial sale de la dirección aunque la página sea otra.
    expect((await read).payload, _payload);
  });
}
