import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/spike_database.dart';
import 'package:mater_studorium/core/db/spike_providers.dart';

import '../helpers/pump_app.dart';
import '../helpers/unmount_app.dart';

void main() {
  testWidgets('Home -> Settings navigation', (tester) async {
    final db = SpikeDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpRouterApp(
      overrides: [spikeDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('На главную'), findsOneWidget);
    await tester.unmountApp();
  });
}
