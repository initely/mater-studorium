// Напоминание в настройках (T19, ТЗ M9, §8.1): тумблер, время, отказ в
// разрешении, web. Планировщик подменён fake: доставку уведомлений тест не
// проверяет.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/reminders/data/reminder_providers.dart';
import 'package:mater_studorium/features/reminders/presentation/reminder_tiles.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/settings/data/settings_providers.dart';
import 'package:mater_studorium/features/settings/domain/settings_repository.dart';
import 'package:mater_studorium/features/settings/domain/user_settings.dart';
import 'package:mater_studorium/features/settings/presentation/settings_screen.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/time_zones.dart';

/// Настройки, у которых не пишется напоминание (диск).
class _BrokenReminder implements SettingsRepository {
  @override
  Future<UserSettings> load() async => const UserSettings(onboardingDone: true);

  @override
  Future<void> setReminderEnabled(bool enabled) =>
      throw const LocalStorageError('диск');

  @override
  Future<void> setReminderMinuteOfDay(int minuteOfDay) async {}

  @override
  Future<void> setNewPerDay(int value) async {}

  @override
  Future<void> setOnboardingDone(bool done) async {}

  @override
  Future<void> setSessionSize(int value) async {}
}

/// `fakeNow`-подобные часы приложения: t0 = 2026-10-11 12:00Z, то есть 15:00 в
/// +03:00; напоминание 20:00 = 17:00Z того же дня.
final _dueNow = FakeSessionRepository(
  contents: [fakeContent('a')],
  states: {'a': fakeState('a', DateTime.utc(2026, 10, 10))},
);

List<Override> _overrides(
  AppDatabase db,
  FakeNotificationScheduler scheduler, {
  FakeSessionRepository? repo,
  TimeOfDay? picked,
}) => [
  ...appOverrides(db),
  notificationSchedulerProvider.overrideWithValue(scheduler),
  sessionRepositoryProvider.overrideWithValue(repo ?? _dueNow),
  utcOffsetProvider.overrideWithValue(fixedOffset(hm(3))),
  timePickerProvider.overrideWithValue(
    (context, initial, help) async => picked,
  ),
];

Future<void> _pumpSettings(
  WidgetTester tester,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const SettingsScreen(), overrides: overrides);
  await tester.pumpAndSettle();
}

bool _switchOn(WidgetTester tester) => tester
    .widget<SwitchListTile>(find.byKey(const Key('reminder-switch')))
    .value;

String _timeText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('reminder-time-value'))).data!;

void main() {
  testWidgets('умолчания: выключено, время 20:00 недоступно для выбора', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler();
    await _pumpSettings(tester, _overrides(memoryDb(), scheduler));

    expect(find.text('Напоминание'), findsOneWidget);
    expect(_switchOn(tester), isFalse);
    expect(_timeText(tester), '20:00');
    expect(
      tester.widget<ListTile>(find.byKey(const Key('reminder-time'))).enabled,
      isFalse,
    );
    expect(find.byKey(const Key('reminder-permission-denied')), findsNothing);
    // Ничего не просили и не ставили, пока пользователь не включил.
    expect(scheduler.requestCalls, 0);
  });

  testWidgets('включение: диалог разрешения, настройка записана, 7 дней', (
    tester,
  ) async {
    final db = memoryDb();
    final scheduler = FakeNotificationScheduler(granted: false);
    await _pumpSettings(tester, _overrides(db, scheduler));

    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    expect(scheduler.requestCalls, 1);
    expect(_switchOn(tester), isTrue);
    expect((await db.settingsDao.readAll())['reminder_enabled'], '1');
    expect(scheduler.scheduled, hasLength(7));
    expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 11, 17));
    expect(scheduler.texts?.title, 'Пора повторить');
    expect(find.byKey(const Key('reminder-permission-denied')), findsNothing);
    expect(
      tester.widget<ListTile>(find.byKey(const Key('reminder-time'))).enabled,
      isTrue,
    );
  });

  testWidgets('отказ в разрешении: тихо, объяснение и переход в настройки', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler(
      granted: false,
      grantOnRequest: false,
    );
    await _pumpSettings(tester, _overrides(memoryDb(), scheduler));

    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    expect(
      _switchOn(tester),
      isTrue,
      reason: 'намерение пользователя хранится',
    );
    expect(scheduler.scheduled, isEmpty);
    expect(find.byKey(const Key('reminder-permission-denied')), findsOneWidget);
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'без всплывающих ошибок',
    );

    await tester.tap(find.byKey(const Key('reminder-open-settings')));
    await tester.pump();
    expect(scheduler.openSettingsCalls, 1);
  });

  testWidgets('выбор времени: пишется в настройки и сдвигает расписание', (
    tester,
  ) async {
    final db = memoryDb();
    await db.settingsDao.write('reminder_enabled', '1');
    final scheduler = FakeNotificationScheduler();
    await _pumpSettings(
      tester,
      _overrides(db, scheduler, picked: const TimeOfDay(hour: 21, minute: 15)),
    );
    await tester.pumpAndSettle();
    expect(scheduler.scheduled, isEmpty, reason: 'без запуска приложения');

    await tester.tap(find.byKey(const Key('reminder-time')));
    await tester.pumpAndSettle();

    expect(_timeText(tester), '21:15');
    expect((await db.settingsDao.readAll())['reminder_minute_of_day'], '1275');
    expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 11, 18, 15));
    expect(scheduler.scheduled, hasLength(7));
  });

  testWidgets('отмена выбора времени ничего не меняет', (tester) async {
    final db = memoryDb();
    await db.settingsDao.write('reminder_enabled', '1');
    final scheduler = FakeNotificationScheduler();
    await _pumpSettings(tester, _overrides(db, scheduler));

    await tester.tap(find.byKey(const Key('reminder-time')));
    await tester.pumpAndSettle();

    expect(_timeText(tester), '20:00');
    expect(scheduler.replaceCalls, 0);
  });

  testWidgets('выключение отменяет поставленные напоминания', (tester) async {
    final db = memoryDb();
    final scheduler = FakeNotificationScheduler();
    await _pumpSettings(tester, _overrides(db, scheduler));
    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();
    expect(scheduler.scheduled, isNotEmpty);

    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    expect(_switchOn(tester), isFalse);
    expect(scheduler.scheduled, isEmpty);
    expect((await db.settingsDao.readAll())['reminder_enabled'], '0');
  });

  testWidgets('нечего повторять: включено, но ничего не ставится', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler();
    await _pumpSettings(
      tester,
      _overrides(memoryDb(), scheduler, repo: FakeSessionRepository()),
    );
    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    expect(_switchOn(tester), isTrue);
    expect(scheduler.scheduled, isEmpty);
    expect(find.byKey(const Key('reminder-permission-denied')), findsNothing);
  });

  testWidgets('web: тумблер недоступен, сказано почему, плагин не трогаем', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler(supported: false);
    await _pumpSettings(tester, _overrides(memoryDb(), scheduler));

    expect(find.byKey(const Key('reminder-unsupported')), findsOneWidget);
    expect(
      find.textContaining('только в приложении для Android'),
      findsOneWidget,
    );
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('reminder-switch')),
    );
    expect(tile.onChanged, isNull);
    expect(tile.value, isFalse);
    expect(find.byKey(const Key('reminder-time')), findsNothing);
    expect(scheduler.initializeCalls, 0);
    expect(scheduler.requestCalls, 0);
  });

  testWidgets('ошибка записи настройки: сообщение, тумблер не включился', (
    tester,
  ) async {
    final scheduler = FakeNotificationScheduler();
    await _pumpSettings(tester, [
      ..._overrides(memoryDb(), scheduler),
      settingsRepositoryProvider.overrideWithValue(_BrokenReminder()),
    ]);

    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось сохранить настройку.'), findsOneWidget);
    expect(_switchOn(tester), isFalse);
  });

  testWidgets('тап-цели не меньше 48 dp, подписи доступны скринридеру', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final scheduler = FakeNotificationScheduler(
      granted: false,
      grantOnRequest: false,
    );
    await _pumpSettings(tester, _overrides(memoryDb(), scheduler));
    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    for (final key in [
      'reminder-switch',
      'reminder-time',
      'reminder-open-settings',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
    expect(
      find.bySemanticsLabel(RegExp('Ежедневное напоминание')),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp('Время напоминания')), findsWidgets);
    handle.dispose();
  });
}
