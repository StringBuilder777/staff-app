import 'package:flutter_test/flutter_test.dart';
import 'package:staff_app/config/backend_config.dart';
import 'package:staff_app/main.dart';

void main() {
  testWidgets('shows operational entry points', (tester) async {
    await tester.pumpWidget(const StaffApp());
    expect(find.text('Registro'), findsOneWidget);
    expect(find.text('Eventos'), findsOneWidget);
  });

  testWidgets('shows participant data after an event NFC read', (tester) async {
    await tester.pumpWidget(const StaffApp());

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

  testWidgets('registration screen shows simulation by default', (tester) async {
    BackendConfig.mode = BackendMode.simulation;
    await tester.pumpWidget(const StaffApp());

    await tester.tap(find.text('Registro'));
    await tester.pumpAndSettle();

    expect(find.text('Simular lectura de QR'), findsOneWidget);
    await tester.tap(find.text('Simular lectura de QR'));
    await tester.pumpAndSettle();

    expect(find.text('Equipo Boreal'), findsOneWidget);
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Escribir NFC'), findsWidgets);
  });

  testWidgets('registration screen removes simulation button when in tunnel mode', (tester) async {
    BackendConfig.mode = BackendMode.tunnel;
    await tester.pumpWidget(const StaffApp());

    await tester.tap(find.text('Registro'));
    await tester.pumpAndSettle();

    // The simulation button is gone
    expect(find.text('Simular lectura de QR'), findsNothing);
    // The backend QR lookup button is shown instead
    expect(find.text('Consultar equipo por QR'), findsOneWidget);
    expect(find.text('Token QR del equipo'), findsOneWidget);

    // Reset back to simulation
    BackendConfig.mode = BackendMode.simulation;
  });
}
