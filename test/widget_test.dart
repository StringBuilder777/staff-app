import 'package:flutter_test/flutter_test.dart';
import 'package:staff_app/config/backend_config.dart';
import 'package:staff_app/main.dart';

/// Arranca la app y entra al flujo del hackathon, que desde la incorporación
/// de SITEC vive detrás de la pantalla de selección de evento.
Future<void> abrirHackathon(WidgetTester tester) async {
  await tester.pumpWidget(const StaffApp());
  await tester.tap(find.text('Hackathon'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows operational entry points', (tester) async {
    // El modo se fija de forma explícita: el valor por defecto de producción es
    // cloud y estas pruebas ejercitan la interfaz de simulación.
    BackendConfig.mode = BackendMode.simulation;
    await abrirHackathon(tester);
    expect(find.text('Registro'), findsOneWidget);
    expect(find.text('Eventos'), findsOneWidget);
  });

  testWidgets('shows participant data after an event NFC read', (tester) async {
    BackendConfig.mode = BackendMode.simulation;
    await abrirHackathon(tester);

    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular lectura NFC'));
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

    await tester.tap(find.text('Registro'));
    await tester.pumpAndSettle();

    expect(find.text('Simular lectura de QR'), findsOneWidget);
    await tester.tap(find.text('Simular lectura de QR'));
    await tester.pumpAndSettle();

    expect(find.text('Equipo Boreal'), findsOneWidget);
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Escribir NFC'), findsWidgets);
  });

  testWidgets(
    'registration screen removes simulation button when in tunnel mode',
    (tester) async {
      BackendConfig.mode = BackendMode.tunnel;
      await abrirHackathon(tester);

      await tester.tap(find.text('Registro'));
      await tester.pumpAndSettle();

      // The simulation button is gone
      expect(find.text('Simular lectura de QR'), findsNothing);
      // The camera scan button and backend QR lookup button are shown instead
      expect(find.text('Abrir cámara para escanear QR'), findsOneWidget);
      expect(find.text('Consultar equipo por QR'), findsOneWidget);
      expect(find.text('Token QR del equipo'), findsOneWidget);

      // Reset back to simulation
      BackendConfig.mode = BackendMode.simulation;
    },
  );
}
