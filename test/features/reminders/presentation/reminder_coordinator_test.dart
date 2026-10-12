// Напоминания и жизнь приложения (T19): тап по уведомлению открывает сессию
// (в том числе при холодном старте), перепланирование на старте, при возврате
// в приложение, после смены часового пояса. Планировщик подменён fake.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/app/router.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/features/reminders/data/reminder_providers.dart';
import 'package:mater_studorium/features/reminders/domain/notification_scheduler.dart';
import 'package:mater_studorium/features/reminders/domain/reminder_service.dart';
import 'package:mater_studorium/features/reminders/presentation/reminder_controller.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/presentation/session_screen.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/time_zones.dart';
import '../../../helpers/unmount_app.dart';

final _due = FakeSessionRepository(
  contents: [fakeContent('a')],
  states: {'a': fakeState('a', DateTime.utc(2026, 10, 10))},
);

/// Пояс, который можно сменить посреди теста (поездка, смена пояса в системе).
class _Zone {
  Duration offset = hm(3);
}

List<Override> _overrides(
  AppDatabase db,
  FakeNotificationScheduler scheduler, {
  _Zone? zone,
}) => [
  ...appOverrides(db),
  notificationSchedulerProvider.overrideWithValue(scheduler),
  sessionRepositoryProvider.overrideWithValue(_due),
  utcOffsetProvider.overrideWithValue((utc) => (zone ?? _Zone()).offset),
];

GoRouter _router(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider);

ReminderStatus _status(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(reminderControllerProvider);

Future<AppDatabase> _onboardedWithReminder() async {
  final db = memoryDb();
  await markOnboarded(db);
  await db.settingsDao.write('reminder_enabled', '1');
  return db;
}

void main() {
  group('тап по уведомлению', () {
    testWidgets('приложение запущено: открывается сессия над главным', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      await tester.pumpRouterApp(
        overrides: _overrides(await _onboardedWithReminder(), scheduler),
      );
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      expect(find.byType(SessionScreen), findsNothing);

      scheduler.tap(kReminderRoute);
      await tester.pumpAndSettle();
      expect(find.byType(SessionScreen), findsOneWidget);

      // «Назад» из сессии ведёт на главный, а не закрывает приложение.
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('холодный старт тапом: сразу сессия, назад на главный', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler(launchRoute: kReminderRoute);
      await tester.pumpRouterApp(
        overrides: _overrides(await _onboardedWithReminder(), scheduler),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SessionScreen), findsOneWidget);
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('сессия уже открыта: второй раз не открывается', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      await tester.pumpRouterApp(
        overrides: _overrides(await _onboardedWithReminder(), scheduler),
      );
      await tester.pumpAndSettle();

      scheduler.tap(kReminderRoute);
      await tester.pumpAndSettle();
      scheduler.tap(kReminderRoute);
      await tester.pumpAndSettle();

      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(
        find.text('Главная'),
        findsOneWidget,
        reason: 'одна сессия, не две',
      );
      await tester.unmountApp();
    });

    testWidgets('до онбординга тап игнорируется', (tester) async {
      final scheduler = FakeNotificationScheduler(launchRoute: kReminderRoute);
      await tester.pumpRouterApp(overrides: _overrides(memoryDb(), scheduler));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-title')), findsOneWidget);
      expect(find.byType(SessionScreen), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('чужой маршрут из уведомления не открывается', (tester) async {
      final scheduler = FakeNotificationScheduler();
      await tester.pumpRouterApp(
        overrides: _overrides(await _onboardedWithReminder(), scheduler),
      );
      await tester.pumpAndSettle();

      scheduler.tap('/settings');
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('платформа без напоминаний: ничего не слушаем и не падаем', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler(
        supported: false,
        launchRoute: kReminderRoute,
      );
      await tester.pumpRouterApp(
        overrides: _overrides(await _onboardedWithReminder(), scheduler),
      );
      await tester.pumpAndSettle();

      expect(find.text('Главная'), findsOneWidget);
      expect(scheduler.initializeCalls, 0);
      expect(_status(tester), ReminderStatus.idle);
      await tester.unmountApp();
    });
  });

  group('перепланирование', () {
    testWidgets('на старте приложения ставится расписание', (tester) async {
      final scheduler = FakeNotificationScheduler();
      await tester.pumpRouterApp(
        overrides: _overrides(await _onboardedWithReminder(), scheduler),
      );
      await tester.pumpAndSettle();

      expect(scheduler.initializeCalls, greaterThan(0));
      // t0 = 2026-10-11 12:00Z, 20:00 в +03:00 = 17:00Z.
      expect(scheduler.scheduled, hasLength(7));
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 11, 17));
      expect(_status(tester), ReminderStatus.scheduled);
      await tester.unmountApp();
    });

    testWidgets('выключено в настройках: на старте ничего не ставится', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      final db = memoryDb();
      await markOnboarded(db);
      await tester.pumpRouterApp(overrides: _overrides(db, scheduler));
      await tester.pumpAndSettle();

      expect(scheduler.scheduled, isEmpty);
      expect(_status(tester), ReminderStatus.disabled);
      await tester.unmountApp();
    });

    testWidgets(
      'возврат в приложение: разрешение дали в системных настройках',
      (tester) async {
        final scheduler = FakeNotificationScheduler(granted: false);
        await tester.pumpRouterApp(
          overrides: _overrides(await _onboardedWithReminder(), scheduler),
        );
        await tester.pumpAndSettle();
        expect(scheduler.scheduled, isEmpty);
        expect(_status(tester), ReminderStatus.permissionDenied);

        scheduler.granted = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(scheduler.scheduled, hasLength(7));
        expect(_status(tester), ReminderStatus.scheduled);
        await tester.unmountApp();
      },
    );

    testWidgets('смена часового пояса: при возврате моменты пересчитаны', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      final zone = _Zone();
      await tester.pumpRouterApp(
        overrides: _overrides(
          await _onboardedWithReminder(),
          scheduler,
          zone: zone,
        ),
      );
      await tester.pumpAndSettle();
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 11, 17));

      // Перелёт в +09:00: 20:00 там — 11:00Z, а сегодня уже 21:00 (12:00Z).
      zone.offset = hm(9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 12, 11));
      await tester.unmountApp();
    });

    testWidgets('уход в фон перепланирует (сессию могли закрыть на середине)', (
      tester,
    ) async {
      final scheduler = FakeNotificationScheduler();
      await tester.pumpRouterApp(
        overrides: _overrides(await _onboardedWithReminder(), scheduler),
      );
      await tester.pumpAndSettle();
      final before = scheduler.replaceCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(scheduler.replaceCalls, before + 1);
      // В паузе кадры не рисуются: вернём приложение, чтобы убрать дерево.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.unmountApp();
    });
  });
}
