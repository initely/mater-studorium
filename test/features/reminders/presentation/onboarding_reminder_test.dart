// Шаг «Напоминание» в онбординге (T19, ТЗ §8.1): виден только там, где
// напоминания работают; по умолчанию выключено; web идёт без этого шага.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/reminders/data/reminder_providers.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/unmount_app.dart';

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Android: четыре шага, напоминание третьим, до колоды', (
    tester,
  ) async {
    final db = memoryDb();
    final scheduler = FakeNotificationScheduler(granted: false);
    await tester.pumpRouterApp(
      overrides: [
        ...appOverrides(db),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Шаг 1 из 4'), findsOneWidget);

    await _next(tester);
    await _next(tester);
    expect(find.text('Шаг 3 из 4'), findsOneWidget);
    expect(find.text('Напоминание'), findsWidgets);
    expect(find.byKey(const Key('reminder-switch')), findsOneWidget);
    expect(find.textContaining('только если есть что повторять'), findsWidgets);
    // По умолчанию выключено, разрешение не просим, пока не включили.
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('reminder-switch')))
          .value,
      isFalse,
    );
    expect(scheduler.requestCalls, 0);

    await _next(tester);
    expect(find.text('Шаг 4 из 4'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-finish')), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('включить напоминание на шаге: разрешение и настройка', (
    tester,
  ) async {
    final db = memoryDb();
    final scheduler = FakeNotificationScheduler(granted: false);
    await tester.pumpRouterApp(
      overrides: [
        ...appOverrides(db),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    await tester.pumpAndSettle();
    await _next(tester);
    await _next(tester);

    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    expect(scheduler.requestCalls, 1);
    expect((await db.settingsDao.readAll())['reminder_enabled'], '1');
    expect(find.text('20:00'), findsOneWidget);

    // Назад и вперёд: выбор сохранился.
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    await _next(tester);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('reminder-switch')))
          .value,
      isTrue,
    );
    await tester.unmountApp();
  });

  testWidgets('«Пропустить» оставляет напоминание выключенным', (tester) async {
    final db = memoryDb();
    final scheduler = FakeNotificationScheduler();
    await tester.pumpRouterApp(
      overrides: [
        ...appOverrides(db),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    await tester.pumpAndSettle();
    await _next(tester);
    await _next(tester);

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.text('Главная'), findsOneWidget);
    expect((await db.settingsDao.readAll())['reminder_enabled'], isNull);
    expect(scheduler.requestCalls, 0);
    expect(scheduler.scheduled, isEmpty);
    await tester.unmountApp();
  });

  testWidgets('web: шага напоминания нет, три шага как раньше', (tester) async {
    final db = memoryDb();
    final scheduler = FakeNotificationScheduler(supported: false);
    await tester.pumpRouterApp(
      overrides: [
        ...appOverrides(db),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Шаг 1 из 3'), findsOneWidget);

    await _next(tester);
    await _next(tester);
    expect(find.text('Шаг 3 из 3'), findsOneWidget);
    expect(find.byKey(const Key('reminder-switch')), findsNothing);
    expect(find.byKey(const Key('onboarding-finish')), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('тап-цели шага напоминания не меньше 48 dp', (tester) async {
    final db = memoryDb();
    await tester.pumpRouterApp(
      overrides: [
        ...appOverrides(db),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await _next(tester);
    await _next(tester);

    for (final key in [
      'reminder-switch',
      'reminder-time',
      'onboarding-next',
      'onboarding-skip',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
    await tester.unmountApp();
  });
}
