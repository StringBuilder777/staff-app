import 'package:flutter_test/flutter_test.dart';
import 'package:staff_app/main.dart';

void main() {
  testWidgets('shows operational entry points', (tester) async {
    await tester.pumpWidget(const StaffApp());
    expect(find.text('Registro'), findsOneWidget);
    expect(find.text('Eventos'), findsOneWidget);
  });
}
