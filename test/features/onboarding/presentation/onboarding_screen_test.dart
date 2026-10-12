// Онбординг и редирект роутера (T18): первый и повторный запуск, холодный
// старт без мигания, пропуск, возврат по шагам, ошибки каталога.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/app/router.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/settings/data/settings_providers.dart';
import 'package:mater_studorium/features/settings/domain/settings_repository.dart';
import 'package:mater_studorium/features/settings/domain/user_settings.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/unmount_app.dart';

/// Настройки, чтение которых завершает тест вручную (медленное хранилище).
class _SlowSettings implements SettingsRepository {
  _SlowSettings(this.value);

  final UserSettings value;
  final gate = Completer<void>();

  @override
  Future<UserSettings> load() async {
    await gate.future;
    return value;
  }

  @override
  Future<void> setNewPerDay(int value) async {}

  @override
  Future<void> setOnboardingDone(bool done) async {}

  @override
  Future<void> setSessionSize(int value) async {}

  @override
  Future<void> setReminderEnabled(bool enabled) async {}

  @override
  Future<void> setReminderMinuteOfDay(int minuteOfDay) async {}
}

GoRouter routerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider);

void main() {
  group('первый запуск', () {
    testWidgets('открывается онбординг, главный не показывается', (
      tester,
    ) async {
      final db = memoryDb();
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-title')), findsOneWidget);
      expect(find.text('Шаг 1 из 3'), findsOneWidget);
      expect(find.text('Главная'), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('глубокая ссылка тоже ведёт на онбординг', (tester) async {
      final db = memoryDb();
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();

      routerOf(tester).go('/settings');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-title')), findsOneWidget);
      expect(find.text('Размер сессии (знаний)'), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('шаги: вперёд, назад, подписи и номер шага', (tester) async {
      final db = memoryDb();
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();

      expect(find.text('Помнить, а не зубрить'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-back')), findsNothing);

      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Сессия на 5 минут'), findsOneWidget);
      expect(find.text('Шаг 2 из 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-back')));
      await tester.pumpAndSettle();
      expect(find.text('Помнить, а не зубрить'), findsOneWidget);
      expect(find.text('Шаг 1 из 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Выберите колоду'), findsOneWidget);
      // На последнем шаге «Пропустить» нет: есть «Выбрать колоду позже».
      expect(find.byKey(const Key('onboarding-skip')), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('«Пропустить»: флаг записан, при следующем запуске сразу '
        'главный', (tester) async {
      final db = memoryDb();
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      expect(find.byKey(const Key('home-no-decks')), findsOneWidget);
      expect(
        await db.settingsDao.readAll(),
        containsPair('onboarding_done', '1'),
      );
      await tester.unmountApp();

      // «Перезапуск»: новое приложение на той же БД.
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-title')), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('без сети: ошибка каталога, «Повторить», выбор колоды '
        'позже ведёт на главный', (tester) async {
      final db = memoryDb();
      final remote = SampleRemote()..fail = const NetworkError('нет сети');
      await tester.pumpRouterApp(overrides: appOverrides(db, remote: remote));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-list-error')), findsOneWidget);
      expect(
        find.text(
          'Не удалось загрузить каталог: нужна сеть. Скачанные колоды доступны.',
        ),
        findsOneWidget,
      );

      remote.fail = null;
      await tester.tap(find.byKey(const Key('onboarding-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-list-error')), findsNothing);
      expect(find.byKey(const Key('deck-action-sample')), findsOneWidget);

      // Колоду не скачали: завершить без неё.
      await tester.tap(find.byKey(const Key('onboarding-finish')));
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      expect(find.byKey(const Key('home-no-decks')), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('тап-цели кнопок онбординга не меньше 48 dp', (tester) async {
      final db = memoryDb();
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();

      for (final key in ['onboarding-next', 'onboarding-skip']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
      }
      await tester.unmountApp();
    });
  });

  group('повторный запуск', () {
    testWidgets('онбординг пройден: сразу главный', (tester) async {
      final db = memoryDb();
      await markOnboarded(db);
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();

      expect(find.text('Главная'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-title')), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('адрес /onboarding после прохождения ведёт на главный', (
      tester,
    ) async {
      final db = memoryDb();
      await markOnboarded(db);
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();

      routerOf(tester).go('/onboarding');
      await tester.pumpAndSettle();

      expect(find.text('Главная'), findsOneWidget);
      await tester.unmountApp();
    });
  });

  group('холодный старт: настройки ещё читаются', () {
    testWidgets('нейтральный экран, затем главный; ни онбординга, ни главного '
        'раньше времени', (tester) async {
      final slow = _SlowSettings(const UserSettings(onboardingDone: true));
      await tester.pumpRouterApp(
        overrides: [
          ...appOverrides(memoryDb()),
          settingsRepositoryProvider.overrideWithValue(slow),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Главная'), findsNothing);
      expect(find.byKey(const Key('onboarding-title')), findsNothing);

      slow.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-title')), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('первый запуск при медленных настройках: сразу онбординг, без '
        'вспышки главного', (tester) async {
      final slow = _SlowSettings(const UserSettings());
      await tester.pumpRouterApp(
        overrides: [
          ...appOverrides(memoryDb()),
          settingsRepositoryProvider.overrideWithValue(slow),
        ],
      );
      await tester.pump();
      expect(find.text('Главная'), findsNothing);

      slow.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-title')), findsOneWidget);
      expect(find.text('Главная'), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('запрошенный адрес сохраняется после загрузки настроек', (
      tester,
    ) async {
      final slow = _SlowSettings(const UserSettings(onboardingDone: true));
      await tester.pumpRouterApp(
        overrides: [
          ...appOverrides(memoryDb()),
          settingsRepositoryProvider.overrideWithValue(slow),
        ],
      );
      await tester.pump();

      routerOf(tester).go('/settings');
      await tester.pump();
      slow.gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Размер сессии (знаний)'), findsOneWidget);
      await tester.unmountApp();
    });
  });
}
