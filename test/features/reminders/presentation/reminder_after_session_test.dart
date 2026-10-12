// Конец сессии двигает напоминание (T19, ТЗ M9: «расписание пересчитывается
// после каждой сессии»). Реальная БД в памяти, настоящий SessionController,
// планировщик подменён fake.
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database_providers.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/reminders/data/reminder_providers.dart';
import 'package:mater_studorium/features/reminders/presentation/reminder_controller.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/domain/session_settings.dart';
import 'package:mater_studorium/features/session/domain/session_state.dart';
import 'package:mater_studorium/features/session/presentation/session_controller.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/session_db_fixtures.dart';
import '../../../helpers/time_zones.dart';

// t0 = 2026-10-11 12:00Z; 20:00 в +03:00 = 17:00Z того же дня.
final _today = DateTime.utc(2026, 10, 11, 17);

/// Перепланирование после сессии идёт в фоне: ждём, пока оно отработает.
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test('ответили на всё просроченное: сегодняшнее напоминание снято', () async {
    final db = memoryDb();
    await db.decksDao.replaceDeck(bigDeck('big', 2), downloadedAt: t0);
    await db.settingsDao.write('reminder_enabled', '1');
    // Одно знание просрочено, второе новое (в сессию не берём: newPerDay 0).
    await answerItem(
      db,
      'big.1',
      at: t0.subtract(const Duration(days: 5)),
      due: t0.subtract(const Duration(days: 1)),
      deckId: 'big',
      questionId: 'big.1.q1',
    );
    final scheduler = FakeNotificationScheduler();
    var ids = 0;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sessionUserIdProvider.overrideWithValue(() => sessionUser),
        clockProvider.overrideWithValue(() => t0),
        randomProvider.overrideWithValue(math.Random(1)),
        uuidGeneratorProvider.overrideWithValue(() => 'log-${ids++}'),
        sessionSettingsProvider.overrideWithValue(
          const SessionSettings(newPerDay: 0),
        ),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        utcOffsetProvider.overrideWithValue(fixedOffset(hm(3))),
      ],
    );
    addTearDown(container.dispose);
    final reminders = container.read(reminderControllerProvider.notifier);
    container.listen(sessionControllerProvider, (_, _) {});

    // До сессии: к 20:00 есть что повторять, напоминания на все дни.
    await reminders.reschedule();
    expect(scheduler.scheduled.first, _today);
    expect(scheduler.scheduled, hasLength(7));

    final before = scheduler.replaceCalls;
    final session = container.read(sessionControllerProvider.notifier);
    await session.start();
    expect(
      container.read(sessionControllerProvider).queue!.items,
      hasLength(1),
    );
    await session.submit(
      rating: Rating.easy,
      gradeSource: GradeSource.auto,
      durationMs: 1000,
    );
    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.finished,
    );
    // Перепланирование запускает сам контроллер сессии, тест его не зовёт.
    await _until(() => scheduler.replaceCalls > before);
    expect(scheduler.replaceCalls, before + 1);

    expect(
      scheduler.scheduled,
      isNot(contains(_today)),
      reason: 'знание уже повторено: сегодня напоминать нечего',
    );
    expect(scheduler.scheduled.every((t) => t.isAfter(_today)), isTrue);
  });

  test('сессию завершили кнопкой: расписание тоже пересчитывается', () async {
    final db = memoryDb();
    await db.decksDao.replaceDeck(bigDeck('big', 2), downloadedAt: t0);
    await db.settingsDao.write('reminder_enabled', '1');
    await answerItem(
      db,
      'big.1',
      at: t0.subtract(const Duration(days: 5)),
      due: t0.subtract(const Duration(days: 1)),
      deckId: 'big',
      questionId: 'big.1.q1',
    );
    final scheduler = FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sessionUserIdProvider.overrideWithValue(() => sessionUser),
        clockProvider.overrideWithValue(() => t0),
        randomProvider.overrideWithValue(math.Random(1)),
        sessionSettingsProvider.overrideWithValue(
          const SessionSettings(newPerDay: 0),
        ),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        utcOffsetProvider.overrideWithValue(fixedOffset(hm(3))),
      ],
    );
    addTearDown(container.dispose);
    container.listen(sessionControllerProvider, (_, _) {});

    final session = container.read(sessionControllerProvider.notifier);
    await session.start();
    expect(scheduler.replaceCalls, 0);
    session.finish();
    await _until(() => scheduler.replaceCalls > 0);

    expect(scheduler.replaceCalls, 1);
  });
}
