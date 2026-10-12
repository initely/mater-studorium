import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/settings/data/settings_providers.dart';
import 'package:mater_studorium/features/settings/domain/settings_repository.dart';
import 'package:mater_studorium/features/settings/domain/user_settings.dart';
import 'package:mater_studorium/features/settings/presentation/settings_screen.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/pump_app.dart';

/// Хранилище, которое отказывает в записи.
class _BrokenWrites implements SettingsRepository {
  @override
  Future<UserSettings> load() async => const UserSettings(onboardingDone: true);

  @override
  Future<void> setNewPerDay(int value) => throw const LocalStorageError('диск');

  @override
  Future<void> setOnboardingDone(bool done) async {}

  @override
  Future<void> setSessionSize(int value) async {}

  @override
  Future<void> setReminderEnabled(bool enabled) async {}

  @override
  Future<void> setReminderMinuteOfDay(int minuteOfDay) async {}
}

String value(WidgetTester tester, String tileKey) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key(tileKey)),
        matching: find.byKey(const Key('stepper-value')),
      ),
    )
    .data!;

Future<void> tapIn(WidgetTester tester, String tileKey, String button) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(Key(tileKey)),
      matching: find.byKey(Key(button)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('умолчания: 10 новых в день, сессия 30 знаний', (tester) async {
    await tester.pumpApp(
      const SettingsScreen(),
      overrides: appOverrides(memoryDb()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Настройки'), findsOneWidget);
    expect(value(tester, 'settings-new-per-day'), '10');
    expect(value(tester, 'settings-session-size'), '30');
  });

  testWidgets('новые в день: шаг 1, значение пишется в хранилище', (
    tester,
  ) async {
    final db = memoryDb();
    await tester.pumpApp(const SettingsScreen(), overrides: appOverrides(db));
    await tester.pumpAndSettle();

    await tapIn(tester, 'settings-new-per-day', 'stepper-increase');
    await tapIn(tester, 'settings-new-per-day', 'stepper-increase');
    expect(value(tester, 'settings-new-per-day'), '12');
    expect((await db.settingsDao.readAll())['new_per_day'], '12');
  });

  testWidgets('размер сессии: шаг 5, границы 5..100', (tester) async {
    final db = memoryDb();
    await db.settingsDao.write('session_size', '10');
    await tester.pumpApp(const SettingsScreen(), overrides: appOverrides(db));
    await tester.pumpAndSettle();

    await tapIn(tester, 'settings-session-size', 'stepper-decrease');
    expect(value(tester, 'settings-session-size'), '5');
    // Ниже минимума кнопка недоступна.
    final decrease = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('settings-session-size')),
        matching: find.byKey(const Key('stepper-decrease')),
      ),
    );
    expect(decrease.onPressed, isNull);
    expect((await db.settingsDao.readAll())['session_size'], '5');
  });

  testWidgets('лимит новых доходит до построителя очереди', (tester) async {
    final db = memoryDb();
    late WidgetRef ref;
    await tester.pumpApp(
      Consumer(
        builder: (context, r, _) {
          ref = r;
          return const SettingsScreen();
        },
      ),
      overrides: appOverrides(db),
    );
    await tester.pumpAndSettle();

    await tapIn(tester, 'settings-new-per-day', 'stepper-decrease');
    await tapIn(tester, 'settings-session-size', 'stepper-increase');

    final settings = ref.read(sessionSettingsProvider);
    expect(settings.newPerDay, 9);
    expect(settings.sessionSize, 35);
  });

  testWidgets('ноль новых в день допустим', (tester) async {
    final db = memoryDb();
    await db.settingsDao.write('new_per_day', '1');
    await tester.pumpApp(const SettingsScreen(), overrides: appOverrides(db));
    await tester.pumpAndSettle();

    await tapIn(tester, 'settings-new-per-day', 'stepper-decrease');
    expect(value(tester, 'settings-new-per-day'), '0');
  });

  testWidgets('ошибка записи: значение прежнее и сообщение', (tester) async {
    await tester.pumpApp(
      const SettingsScreen(),
      overrides: [
        ...appOverrides(memoryDb()),
        settingsRepositoryProvider.overrideWithValue(_BrokenWrites()),
      ],
    );
    await tester.pumpAndSettle();

    await tapIn(tester, 'settings-new-per-day', 'stepper-increase');

    expect(value(tester, 'settings-new-per-day'), '10');
    expect(find.text('Не удалось сохранить настройку.'), findsOneWidget);
  });

  testWidgets('доступность: кнопки с подсказками и тап-цель 48 dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpApp(
      const SettingsScreen(),
      overrides: appOverrides(memoryDb()),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Меньше'), findsNWidgets(2));
    expect(find.byTooltip('Больше'), findsNWidgets(2));
    final size = tester.getSize(
      find.descendant(
        of: find.byKey(const Key('settings-new-per-day')),
        matching: find.byKey(const Key('stepper-increase')),
      ),
    );
    expect(size.shortestSide, greaterThanOrEqualTo(48));
    handle.dispose();
  });
}
