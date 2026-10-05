import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_app/config/backend_config.dart';
import 'package:staff_app/main.dart';

const _hostApi = 'dev.flutter.pigeon.nfc_manager.HostApiPigeon.';

/// Responde por el lado nativo de `nfc_manager` en Android. La respuesta es la
/// lista que manda Pigeon: `[valor]` si va bien y `[código, mensaje, detalles]`
/// si falla.
void _answer(WidgetTester tester, String method, List<Object?> Function() reply) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMessageHandler(
    '$_hostApi$method',
    (_) async => const StandardMessageCodec().encodeMessage(reply()),
  );
  addTearDown(() => messenger.setMockMessageHandler('$_hostApi$method', null));
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
}
