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

void main() {
  testWidgets('shows operational entry points', (tester) async {
    // El modo se fija de forma explícita: el valor por defecto de producción es
    // cloud y estas pruebas ejercitan la interfaz de simulación.
    BackendConfig.mode = BackendMode.simulation;
    await abrirHackathon(tester);
    expect(find.text('REGISTRO'), findsOneWidget);
    expect(find.text('EVENTOS'), findsOneWidget);
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
}
