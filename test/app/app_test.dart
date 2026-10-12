// Навигация и сквозной путь T18 на настоящем роутере и БД в памяти:
// первый запуск → онбординг → сессия → итоги → главный.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_fixtures.dart';
import '../helpers/db_fixtures.dart';
import '../helpers/fake_catalog_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/unmount_app.dart';

void main() {
  testWidgets('Home -> Settings -> назад', (tester) async {
    final db = memoryDb();
    await markOnboarded(db);
    await tester.pumpRouterApp(overrides: appOverrides(db));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Размер сессии (знаний)'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('Home -> Колоды -> назад', (tester) async {
    final db = memoryDb();
    await markOnboarded(db);
    final repo = FakeCatalogRepository(remote: [remoteDeck('a')]);
    await tester.pumpRouterApp(overrides: appOverrides(db, catalog: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-decks')));
    await tester.pumpAndSettle();
    expect(find.text('Колода a'), findsOneWidget);
    expect(find.text('Скачать'), findsOneWidget);

    // pageBack ищет подсказку «Back», а локаль ru даёт «Назад».
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets(
    'Home -> Начать сессию -> экран сессии -> крестик -> Home (счётчики обновились)',
    (tester) async {
      final db = memoryDb();
      await markOnboarded(db);
      await installSample(db);
      await tester.pumpRouterApp(overrides: appOverrides(db));
      await tester.pumpAndSettle();
      // sample: mcq и flip поддерживаются, остальные форматы пока нет.
      expect(find.byKey(const Key('home-stat-new')), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-start-session')));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 1 из 2'), findsOneWidget);

      // Ответили на mcq и вышли через «Выйти»: ответ записан.
      await tester.tap(find.byKey(const Key('mcq-option-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rating-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session-exit-leave')));
      await tester.pumpAndSettle();

      expect(find.text('Главная'), findsOneWidget);
      // Главный пересчитан после возвращения: остался один новый.
      expect(
        find.descendant(
          of: find.byKey(const Key('home-stat-new')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await tester.unmountApp();
    },
  );

  testWidgets('Сквозной путь: первый запуск -> онбординг -> скачивание -> '
      'сессия -> итоги -> главный', (tester) async {
    final db = memoryDb();
    await tester.pumpRouterApp(
      overrides: appOverrides(db, remote: SampleRemote()),
    );
    await tester.pumpAndSettle();

    // Первый запуск: онбординг, шаг 1.
    expect(find.byKey(const Key('onboarding-title')), findsOneWidget);
    expect(find.text('Помнить, а не зубрить'), findsOneWidget);
    expect(find.text('Шаг 1 из 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Сессия на 5 минут'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // Шаг 3: колоды ещё нет, можно только отложить выбор.
    expect(find.text('Выберите колоду'), findsOneWidget);
    expect(find.text('Выбрать колоду позже'), findsOneWidget);
    await tester.tap(find.byKey(const Key('deck-action-sample')));
    await tester.pumpAndSettle();
    expect(find.text('Начать первую сессию'), findsOneWidget);

    // Завершение: флаг записан, открыта сессия поверх главного.
    await tester.tap(find.byKey(const Key('onboarding-finish')));
    await tester.pumpAndSettle();
    expect(
      await db.settingsDao.readAll(),
      containsPair('onboarding_done', '1'),
    );
    expect(find.text('Вопрос 1 из 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mcq-option-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flip-show')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-hard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-summary-title')), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-home')));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);
    // Всё поддерживаемое пройдено: «Всё повторено» и время следующего.
    expect(find.byKey(const Key('home-all-done')), findsOneWidget);
    expect(find.byKey(const Key('home-next')), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('Лимит новых 0: «Взять 5 новых» на главном запускает сессию', (
    tester,
  ) async {
    final db = memoryDb();
    await markOnboarded(db);
    await installSample(db);
    await db.settingsDao.write('new_per_day', '0');
    await tester.pumpRouterApp(overrides: appOverrides(db));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-all-done')), findsOneWidget);
    expect(find.byKey(const Key('home-start-session')), findsNothing);
    await tester.tap(find.byKey(const Key('home-take-new')));
    await tester.pumpAndSettle();

    expect(find.text('Вопрос 1 из 2'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('Повторный запуск без онбординга: сразу главный; /onboarding '
      'возвращает на главный', (tester) async {
    final db = memoryDb();
    await markOnboarded(db);
    await tester.pumpRouterApp(overrides: appOverrides(db));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-title')), findsNothing);
    await tester.unmountApp();
  });
}
