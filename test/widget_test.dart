import 'package:flutter_test/flutter_test.dart';
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
}
