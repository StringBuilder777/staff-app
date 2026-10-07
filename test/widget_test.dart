import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_app/config/backend_config.dart';
import 'package:staff_app/main.dart';

/// Arranca la app y entra al flujo del hackathon, que desde la incorporación
/// de SITEC vive detrás de la pantalla de selección de evento.
Future<void> abrirHackathon(WidgetTester tester) async {
  await tester.pumpWidget(const StaffApp());
  // El sistema de diseño pinta los títulos en mayúsculas.
  await tester.tap(find.text('HACKATHON'));
  await tester.pumpAndSettle();
}

/// Arranca la app y entra a SITEC desde la selección de evento.
Future<void> abrirSitec(WidgetTester tester) async {
  await tester.pumpWidget(const StaffApp());
  await tester.tap(find.text('SITEC'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows operational entry points', (tester) async {
    // El modo se fija de forma explícita: el valor por defecto de producción es
    // cloud y estas pruebas ejercitan la interfaz de simulación.
    BackendConfig.mode = BackendMode.simulation;
    await abrirHackathon(tester);
    expect(find.text('REGISTRO'), findsOneWidget);
    expect(find.text('EVENTOS'), findsOneWidget);
  });

  testWidgets('hackathon accesses are grouped by day', (tester) async {
    // Pantalla alta: caben los dos días sin desplazar, y así se comparan sus
    // posiciones.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    BackendConfig.mode = BackendMode.simulation;
    await abrirHackathon(tester);
    await tester.tap(find.text('EVENTOS'));
    await tester.pumpAndSettle();

    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    // El viernes la llegada y la cena; el sábado el desayuno, la comida y la
    // salida.
    const order = [
      'VIERNES',
      'CHECK-IN',
      'CENA',
      'SÁBADO',
      'DESAYUNO',
      'COMIDA',
      'CHECK-OUT',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i - 1]), lessThan(top(order[i])), reason: order[i]);
    }
  });

  testWidgets('shows participant data after an event NFC read', (tester) async {
    BackendConfig.mode = BackendMode.simulation;
    await abrirHackathon(tester);

    await tester.tap(find.text('EVENTOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHECK-IN'));
    await tester.pumpAndSettle();
    // PrimaryAction pinta las etiquetas en versales.
    await tester.tap(find.text('SIMULAR LECTURA NFC'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Equipo Boreal'), findsOneWidget);
    expect(find.text('Acceso válido'), findsOneWidget);
  });

  testWidgets('registration screen shows simulation by default', (
    tester,
  ) async {
    BackendConfig.mode = BackendMode.simulation;
    await abrirHackathon(tester);

    await tester.tap(find.text('REGISTRO'));
    await tester.pumpAndSettle();

    expect(find.text('SIMULAR LECTURA DE QR'), findsOneWidget);
    await tester.tap(find.text('SIMULAR LECTURA DE QR'));
    await tester.pumpAndSettle();

    expect(find.text('Equipo Boreal'), findsOneWidget);
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('ESCRIBIR NFC'), findsWidgets);
  });

  testWidgets(
    'registration screen removes simulation button when in tunnel mode',
    (tester) async {
      BackendConfig.mode = BackendMode.tunnel;
      await abrirHackathon(tester);

      await tester.tap(find.text('REGISTRO'));
      await tester.pumpAndSettle();

      // The simulation button is gone
      expect(find.text('SIMULAR LECTURA DE QR'), findsNothing);
      // Solo queda el escaneo por cámara: la entrada manual del token se
      // retiró para dejar un único camino.
      expect(find.text('ABRIR CÁMARA Y ESCANEAR QR'), findsOneWidget);
      expect(find.text('Consultar equipo por QR'), findsNothing);
      expect(find.text('Token QR del equipo'), findsNothing);

      // Reset back to simulation
      BackendConfig.mode = BackendMode.simulation;
    },
  );

  testWidgets('SITEC shows registration and both days', (tester) async {
    BackendConfig.mode = BackendMode.simulation;
    await abrirSitec(tester);

    expect(find.text('REGISTRO'), findsOneWidget);
    expect(find.text('JUEVES'), findsOneWidget);
    expect(find.text('VIERNES'), findsOneWidget);
  });

  testWidgets('SITEC days keep their own order of access points', (
    tester,
  ) async {
    BackendConfig.mode = BackendMode.simulation;
    await abrirSitec(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    // El jueves la comida va antes que la salida; el viernes, al revés.
    await tester.tap(find.text('JUEVES'));
    await tester.pumpAndSettle();
    expect(top('ENTRADA'), lessThan(top('COMIDA')));
    expect(top('COMIDA'), lessThan(top('SALIDA')));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIERNES'));
    await tester.pumpAndSettle();
    expect(top('ENTRADA'), lessThan(top('SALIDA')));
    expect(top('SALIDA'), lessThan(top('COMIDA')));
  });

  testWidgets('SITEC access point reads NFC without a team', (tester) async {
    BackendConfig.mode = BackendMode.simulation;
    await abrirSitec(tester);

    await tester.tap(find.text('JUEVES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTRADA'));
    await tester.pumpAndSettle();

    expect(find.text('01 / SITEC · JUEVES'), findsOneWidget);

    await tester.tap(find.text('SIMULAR LECTURA NFC'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Acceso válido'), findsOneWidget);
    expect(find.text('Equipo Boreal'), findsNothing);
    // Título de la barra y fila de evento del resultado.
    expect(find.text('Jueves · Entrada'), findsNWidgets(2));
  });

  testWidgets('SITEC registration finds an attendee and writes the card', (
    tester,
  ) async {
    // Pantalla de teléfono: en el lienzo por defecto (800 × 600) la lista no
    // llega a construir la última fila.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    BackendConfig.mode = BackendMode.simulation;
    await abrirSitec(tester);

    await tester.tap(find.text('REGISTRO'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Sofía Treviño'), findsOneWidget);

    // Sin tildes, sin mayúsculas y en cualquier orden.
    await tester.enterText(find.byType(TextField), 'trevino SOF');
    await tester.pumpAndSettle();
    expect(find.text('Sofía Treviño'), findsOneWidget);
    expect(find.text('Ana Torres'), findsNothing);

    await tester.tap(find.text('ESCRIBIR NFC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIMULAR ESCRITURA'));
    await tester.pumpAndSettle();

    expect(find.text('Tarjeta escrita'), findsOneWidget);
    expect(find.text('Tarjeta de Sofía Treviño escrita.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nadie coincide con «zzz».'), findsOneWidget);
  });

  testWidgets('SITEC registration offers a retry when the list fails', (
    tester,
  ) async {
    // Fuera de simulación la lista viene del backend; en las pruebas todas las
    // peticiones HTTP fallan, que es justo el caso que se quiere ver.
    BackendConfig.mode = BackendMode.tunnel;
    addTearDown(() => BackendConfig.mode = BackendMode.simulation);
    await abrirSitec(tester);

    await tester.tap(find.text('REGISTRO'));
    await tester.pumpAndSettle();

    expect(find.text('SIN LISTA'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });
}
