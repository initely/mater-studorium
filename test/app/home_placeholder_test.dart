import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/app/home_placeholder.dart';
import 'package:mater_studorium/core/db/spike_database.dart';
import 'package:mater_studorium/core/db/spike_providers.dart';

import '../helpers/fixed_clock.dart';
import '../helpers/pump_app.dart';
import '../helpers/unmount_app.dart';

void main() {
  testWidgets('HomePlaceholder показывает заголовок и кнопку настроек', (
    tester,
  ) async {
    final db = SpikeDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpApp(
      const HomePlaceholder(),
      overrides: [spikeDatabaseProvider.overrideWithValue(db)],
    );
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
    await tester.unmountApp();
  });

  // ВРЕМЕННО (T05): spike drift, удалить при T09.
  testWidgets('spike: кнопка добавляет запись со временем из clockProvider', (
    tester,
  ) async {
    final db = SpikeDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpApp(
      const HomePlaceholder(),
      overrides: [
        spikeDatabaseProvider.overrideWithValue(db),
        fixedClock(DateTime.utc(2026, 10, 11, 12)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Записей пока нет'), findsOneWidget);

    await tester.tap(find.text('Добавить запись (spike)'));
    await tester.pumpAndSettle();

    expect(find.text('Записей пока нет'), findsNothing);
    expect(find.text('Запись 1 — 2026-10-11T12:00:00.000Z'), findsOneWidget);
    await tester.unmountApp();
  });
}
