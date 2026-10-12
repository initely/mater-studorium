// Экран колоды на настоящем роутере и БД в памяти (T18): описание, прогресс,
// лимит новых, обновление, «Начать по этой колоде», удаление с подтверждением.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/session_db_fixtures.dart';
import '../../../helpers/unmount_app.dart';

/// Открывает приложение и переходит на экран колоды [deckId] через «Колоды».
Future<void> openDeck(
  WidgetTester tester,
  AppDatabase db, {
  SampleRemote? remote,
  String deckId = 'sample',
}) async {
  await tester.pumpRouterApp(
    overrides: appOverrides(db, remote: remote ?? SampleRemote()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('home-decks')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('deck-$deckId')));
  await tester.pumpAndSettle();
}

int count(WidgetTester tester, String key) {
  final text = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(Text),
  );
  return int.parse(tester.widget<Text>(text.last).data!);
}

Future<AppDatabase> dbWithSample() async {
  final db = memoryDb();
  await markOnboarded(db);
  await installSample(db);
  return db;
}

void main() {
  testWidgets('описание, версия, число знаний и прогресс по стадиям FSRS', (
    tester,
  ) async {
    final db = await dbWithSample();
    // infosec.xss.reflected — learning, infosec.http.hsts — review,
    // infosec.sqli.parameterized — новое.
    await db.reviewDao.recordReview(
      userId: sessionUser,
      log: logFor('infosec.xss.reflected', id: 'l1'),
      state: stateFor(
        'infosec.xss.reflected',
        deckId: 'sample',
        due: t0,
      ).copyWith(state: SrsState.relearning),
    );
    await db.reviewDao.recordReview(
      userId: sessionUser,
      log: logFor('infosec.http.hsts', id: 'l2'),
      state: stateFor('infosec.http.hsts', deckId: 'sample', due: t0),
    );

    await openDeck(tester, db);

    expect(find.text('Пример колоды: основы веб-безопасности'), findsOneWidget);
    expect(find.textContaining('Образец формата колоды'), findsOneWidget);
    expect(find.text('Версия 1 · 3 знания'), findsOneWidget);
    expect(count(tester, 'deck-progress-new'), 1);
    expect(count(tester, 'deck-progress-learning'), 1);
    expect(count(tester, 'deck-progress-mastered'), 1);
    // Не только цвет: у каждой строки есть подпись.
    expect(find.text('Новые'), findsOneWidget);
    expect(find.text('Изучаемые'), findsOneWidget);
    expect(find.text('Выученные'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('прогресс обновляется, пока экран открыт (ответ в сессии)', (
    tester,
  ) async {
    final db = await dbWithSample();
    await openDeck(tester, db);
    expect(count(tester, 'deck-progress-new'), 3);

    await db.reviewDao.recordReview(
      userId: sessionUser,
      log: logFor('infosec.http.hsts', id: 'l1'),
      state: stateFor('infosec.http.hsts', deckId: 'sample', due: t0),
    );
    await tester.pumpAndSettle();

    expect(count(tester, 'deck-progress-new'), 2);
    expect(count(tester, 'deck-progress-mastered'), 1);
    await tester.unmountApp();
  });

  testWidgets('озвучка прогресса: одна строка с числами', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await dbWithSample();
    await openDeck(tester, db);

    expect(
      find.bySemanticsLabel(
        'Прогресс по колоде: новых 3, изучаемых 0, выученных 0',
      ),
      findsOneWidget,
    );
    handle.dispose();
    await tester.unmountApp();
  });

  testWidgets('лимит новых в день пишется в настройки и общий для колод', (
    tester,
  ) async {
    final db = await dbWithSample();
    await openDeck(tester, db);

    expect(
      tester.widget<Text>(find.byKey(const Key('stepper-value'))).data,
      '10',
    );
    await tester.tap(find.byKey(const Key('stepper-increase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stepper-increase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stepper-decrease')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('stepper-value'))).data,
      '11',
    );
    expect((await db.settingsDao.readAll())['new_per_day'], '11');
    // Тап-цель кнопок не меньше 48 dp.
    final size = tester.getSize(find.byKey(const Key('stepper-increase')));
    expect(size.shortestSide, greaterThanOrEqualTo(48));
    await tester.unmountApp();
  });

  testWidgets('«Начать по этой колоде» берёт знания только этой колоды', (
    tester,
  ) async {
    final db = await dbWithSample();
    await db.decksDao.replaceDeck(bigDeck('big', 3), downloadedAt: t0);
    await openDeck(tester, db, deckId: 'big');

    await tester.tap(find.byKey(const Key('deck-start')));
    await tester.pumpAndSettle();

    // big: три знания с flip; два знания sample (mcq и flip) в очередь
    // не входят (без фильтра было бы «из 5»).
    expect(find.text('Вопрос 1 из 3'), findsOneWidget);
    await tester.unmountApp();
  });

  group('обновление', () {
    testWidgets('новая версия на сервере: колода обновляется', (tester) async {
      final db = await dbWithSample();
      await openDeck(tester, db, remote: SampleRemote(version: 2));

      await tester.ensureVisible(find.byKey(const Key('deck-update')));
      await tester.tap(find.byKey(const Key('deck-update')));
      await tester.pumpAndSettle();

      expect(find.text('Колода обновлена до версии 2'), findsOneWidget);
      expect(find.text('Версия 2 · 3 знания'), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('версия та же: сообщение «последняя версия»', (tester) async {
      final db = await dbWithSample();
      await openDeck(tester, db);

      await tester.ensureVisible(find.byKey(const Key('deck-update')));
      await tester.tap(find.byKey(const Key('deck-update')));
      await tester.pumpAndSettle();

      expect(find.text('Установлена последняя версия'), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('нет сети: понятная ошибка, версия прежняя', (tester) async {
      final db = await dbWithSample();
      final remote = SampleRemote(version: 2);
      await openDeck(tester, db, remote: remote);
      remote.fail = const NetworkError('нет сети');

      await tester.ensureVisible(find.byKey(const Key('deck-update')));
      await tester.tap(find.byKey(const Key('deck-update')));
      await tester.pumpAndSettle();

      expect(find.text('Нужна сеть, чтобы скачать колоду'), findsOneWidget);
      expect(find.text('Версия 1 · 3 знания'), findsOneWidget);
      await tester.unmountApp();
    });
  });

  group('удаление', () {
    testWidgets('отмена в диалоге ничего не удаляет', (tester) async {
      final db = await dbWithSample();
      await openDeck(tester, db);

      await tester.scrollUntilVisible(
        find.byKey(const Key('deck-delete')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('deck-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Удалить колоду?'), findsOneWidget);
      expect(find.textContaining('Ваш прогресс сохранится'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deck-delete-cancel')));
      await tester.pumpAndSettle();

      expect(await db.decksDao.getDeck('sample'), isNotNull);
      expect(find.byKey(const Key('deck-delete')), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('подтверждение удаляет колоду, прогресс остаётся', (
      tester,
    ) async {
      final db = await dbWithSample();
      await db.reviewDao.recordReview(
        userId: sessionUser,
        log: logFor('infosec.http.hsts', id: 'l1'),
        state: stateFor('infosec.http.hsts', deckId: 'sample', due: t0),
      );
      await openDeck(tester, db);

      await tester.scrollUntilVisible(
        find.byKey(const Key('deck-delete')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('deck-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deck-delete-confirm')));
      await tester.pumpAndSettle();

      expect(await db.decksDao.getDeck('sample'), isNull);
      expect(await db.select(db.items).get(), isEmpty);
      expect(await db.select(db.userItemStates).get(), hasLength(1));
      expect(await db.select(db.reviewLogs).get(), hasLength(1));
      // Вернулись в каталог: колода доступна к скачиванию.
      expect(find.byKey(const Key('deck-action-sample')), findsOneWidget);
      expect(find.text('Скачать'), findsOneWidget);
      await tester.unmountApp();
    });
  });

  testWidgets('колоды нет на устройстве: сообщение вместо экрана', (
    tester,
  ) async {
    final db = memoryDb();
    await markOnboarded(db);
    await tester.pumpRouterApp(
      overrides: appOverrides(db, remote: SampleRemote()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Главная'));
    // Прямой переход на адрес колоды, которой нет локально.
    context.go('/decks/ghost');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deck-missing')), findsOneWidget);
    expect(find.text('Этой колоды нет на устройстве'), findsOneWidget);
    await tester.unmountApp();
  });
}
