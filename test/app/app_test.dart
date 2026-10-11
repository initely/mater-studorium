import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('Home -> Settings navigation', (tester) async {
    await tester.pumpRouterApp();
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('На главную'), findsOneWidget);
  });
}
