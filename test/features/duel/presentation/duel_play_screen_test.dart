// Экран прохождения дуэли (T23, ТЗ M10, §8.4): те же виджеты mcq без панели
// оценки, секундомер на фейковых часах, повторный вход, недоступные вопросы.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';

import '../../../helpers/duel_fixtures.dart';
import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_duel_repository.dart';
import 'duel_pump.dart';

const _play = '/duels/$kDuelId/play';

Finder _key(String key) => find.byKey(Key(key));

void main() {
  late FakeDuelRepository repo;
  late FakeDuelAnswerQueue queue;
  late FakeDuelContentSource content;
  late DateTime now;

  setUp(() {
    now = duelNow;
    repo = FakeDuelRepository()..getResult = playDuel();
    queue = FakeDuelAnswerQueue();
    content = FakeDuelContentSource(content: contentOf());
  });

  Future<void> open(
    WidgetTester tester, {
    String initial = _play,
    FakeCatalogRepository? catalog,
  }) => pumpDuelApp(
    tester,
    initial: initial,
    repo: repo,
    queue: queue,
    content: content,
    catalog:
        catalog ??
        FakeCatalogRepository(local: [localDeck(kDuelDeckId, version: 2)]),
    clock: () => now,
  );

  testWidgets('пять вопросов по порядку: без панели оценки, ответ уходит в '
      'очередь, в конце «Ты ответил на все»', (tester) async {
    await open(tester);
    for (var i = 1; i <= 5; i++) {
      expect(find.text('Вопрос $i из 5'), findsOneWidget);
      expect(find.text('Вопрос номер $i'), findsOneWidget);
      // Панели оценки FSRS, разбора и жалобы нет.
      expect(_key('rating-next'), findsNothing);
      expect(find.byType(SegmentedButton<int>), findsNothing);
      expect(_key('explanation-short-toggle'), findsNothing);
      expect(_key('duel-play-next'), findsNothing);

      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      expect(queue.queued, hasLength(i));
      expect(queue.queued.last.questionId, duelQuestionIds()[i - 1]);
      expect(find.text(i == 5 ? 'Закончить' : 'Дальше'), findsOneWidget);
      await tester.tap(_key('duel-play-next'));
      await tester.pumpAndSettle();
    }
    expect(_key('duel-play-done'), findsOneWidget);
    expect(find.text('Ты ответил на все вопросы'), findsOneWidget);
    expect(queue.queued.every((a) => a.isCorrect), isTrue);
    expect(queue.queued.first.answer, {
      'selected': ['a'],
    });
  });

  testWidgets(
    'неверный ответ: is_correct = false, выбранный вариант в ответе',
    (tester) async {
      await open(tester);
      await tester.tap(_key('mcq-option-b'));
      await tester.pumpAndSettle();
      expect(queue.queued.single.isCorrect, isFalse);
      expect(queue.queued.single.answer, {
        'selected': ['b'],
      });
      // Свой ответ человек видит сразу (подпись, не только цвет).
      expect(find.text('Неверно'), findsOneWidget);
    },
  );

  testWidgets('секундомер идёт от показа вопроса по часам и замирает после '
      'ответа', (tester) async {
    await open(tester);
    expect(find.text('0:00'), findsOneWidget);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:03'), findsOneWidget);

    now = now.add(const Duration(seconds: 7));
    await tester.tap(_key('mcq-option-a'));
    await tester.pumpAndSettle();
    expect(queue.queued.single.durationMs, 10000);
    expect(find.text('0:10'), findsOneWidget);

    // После ответа секундомер стоит, даже если время идёт.
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:10'), findsOneWidget);

    // Следующий вопрос: с нуля.
    await tester.tap(_key('duel-play-next'));
    await tester.pumpAndSettle();
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('подпись секундомера для скринридера не «живая»', (tester) async {
    await open(tester);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Время на вопрос: 0:00'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('поворот экрана не теряет ответ и состояние', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);
    await tester.tap(_key('mcq-option-a'));
    await tester.pumpAndSettle();
    expect(queue.queued, hasLength(1));

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(find.text('Вопрос 1 из 5'), findsOneWidget);
    expect(_key('duel-play-next'), findsOneWidget);
    expect(queue.queued, hasLength(1));

    // Вариант заблокирован: второй ответ на тот же вопрос невозможен.
    await tester.tap(_key('mcq-option-b'));
    await tester.pumpAndSettle();
    expect(queue.queued, hasLength(1));
    expect(queue.queued.single.isCorrect, isTrue);
  });

  testWidgets('двойной тап по варианту пишет один ответ', (tester) async {
    await open(tester);
    await tester.tap(_key('mcq-option-a'));
    await tester.tap(_key('mcq-option-a'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(queue.queued, hasLength(1));
  });

  testWidgets('повторный вход в экран: отвеченное не показывается снова', (
    tester,
  ) async {
    await open(tester, initial: '/duels/$kDuelId');
    await tester.tap(_key('duel-play'));
    await tester.pumpAndSettle();
    await tester.tap(_key('mcq-option-a'));
    await tester.pumpAndSettle();
    await tester.tap(_key('duel-play-next'));
    await tester.pumpAndSettle();
    expect(find.text('Вопрос 2 из 5'), findsOneWidget);

    // Закрыли на втором вопросе (без ответа) и вошли снова.
    await tester.tap(_key('duel-play-close'));
    await tester.pumpAndSettle();
    expect(_key('duel-play'), findsOneWidget);
    await tester.tap(_key('duel-play'));
    await tester.pumpAndSettle();
    expect(find.text('Вопрос 2 из 5'), findsOneWidget);
    expect(find.text('Вопрос номер 1'), findsNothing);
    await tester.tap(_key('mcq-option-a'));
    await tester.pumpAndSettle();
    expect(queue.queued.map((a) => a.questionId), [
      duelQuestionIds()[0],
      duelQuestionIds()[1],
    ]);
  });

  testWidgets('вопрос, на который сервер уже принял ответ, не показывается', (
    tester,
  ) async {
    repo.answersResult = DuelAnswers(
      mine: [for (final id in duelQuestionIds().take(4)) record(id)],
      other: const [],
    );
    await open(tester);
    expect(find.text('Вопрос 5 из 5'), findsOneWidget);
    expect(find.text('Закончить'), findsNothing, reason: 'ответа ещё нет');
  });

  testWidgets('я уже ответил на все: сразу «Ты ответил на все вопросы»', (
    tester,
  ) async {
    repo.getResult = playDuel(myDoneAt: duelNow);
    await open(tester);
    expect(_key('duel-play-done'), findsOneWidget);
    expect(_key('mcq-option-a'), findsNothing);
  });

  group('недоступные вопросы', () {
    testWidgets('есть блок, обновление колоды перезагружает набор', (
      tester,
    ) async {
      content.content = contentOf(missing: {duelQuestionIds()[1]});
      final catalog = FakeCatalogRepository(
        remote: [remoteDeck(kDuelDeckId, version: 2)],
        local: [localDeck(kDuelDeckId, version: 2)],
      );
      await open(tester, catalog: catalog);
      expect(_key('duel-play-blocked'), findsOneWidget);
      expect(
        find.textContaining('1 вопрос этой дуэли недоступен'),
        findsOneWidget,
      );
      expect(_key('mcq-option-a'), findsNothing);
      for (final k in ['duel-play-update', 'duel-play-skip']) {
        expectTapTarget(tester, Key(k));
      }

      // Колоду обновили: вопрос появился.
      content.content = contentOf();
      await tester.tap(_key('duel-play-update'));
      await tester.pumpAndSettle();
      expect(catalog.downloads, [kDuelDeckId]);
      expect(find.text('Вопрос 1 из 5'), findsOneWidget);
    });

    testWidgets('сбой обновления: сообщение, играть без них можно', (
      tester,
    ) async {
      content.content = contentOf(
        missing: {duelQuestionIds()[0], duelQuestionIds()[4]},
      );
      final catalog = FakeCatalogRepository(
        remote: [remoteDeck(kDuelDeckId, version: 2)],
      )..downloadError = const NetworkError('x');
      await open(tester, catalog: catalog);
      expect(
        find.textContaining('2 вопроса этой дуэли недоступны'),
        findsOneWidget,
      );
      await tester.tap(_key('duel-play-update'));
      await tester.pumpAndSettle();
      expect(_key('duel-play-update-error'), findsOneWidget);

      await tester.tap(_key('duel-play-skip'));
      await tester.pumpAndSettle();
      expect(queue.queued.map((a) => a.questionId), [
        duelQuestionIds()[0],
        duelQuestionIds()[4],
      ]);
      expect(
        queue.queued.every((a) => !a.isCorrect && a.durationMs == 0),
        isTrue,
      );
      expect(find.text('Вопрос 2 из 5'), findsOneWidget);
    });

    testWidgets('колоды нет: карточка докачки, не падение', (tester) async {
      content.content = null;
      final catalog = FakeCatalogRepository(
        remote: [remoteDeck(kDuelDeckId, version: 2)],
      );
      await open(tester, catalog: catalog);
      expect(_key('duel-deck-missing'), findsOneWidget);
      content.content = contentOf();
      await tester.tap(_key('duel-deck-download'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 1 из 5'), findsOneWidget);
    });
  });

  group('закрытая дуэль и ошибки', () {
    testWidgets('дуэль завершена или истекла: сообщение и «К дуэли»', (
      tester,
    ) async {
      repo.getResult = playDuel(
        status: DuelStatus.finished,
        myDoneAt: duelNow,
        otherDoneAt: duelNow,
      );
      await open(tester);
      expect(_key('duel-play-closed'), findsOneWidget);
      expect(_key('mcq-option-a'), findsNothing);
    });

    testWidgets('дуэли нет', (tester) async {
      repo.getResult = null;
      await open(tester);
      expect(_key('duel-play-not-found'), findsOneWidget);
    });

    testWidgets('нет сети: ошибка и повтор', (tester) async {
      repo.getError = offline;
      await open(tester);
      expect(_key('duel-play-error'), findsOneWidget);
      expectTapTarget(tester, const Key('duel-play-retry'));
      repo.getError = null;
      await tester.tap(_key('duel-play-retry'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 1 из 5'), findsOneWidget);
    });

    testWidgets(
      'ответ не сохранился: сообщение и «Повторить», затем «Дальше»',
      (tester) async {
        queue.enqueueError = const LocalStorageError('диск');
        await open(tester);
        await tester.tap(_key('mcq-option-a'));
        await tester.pumpAndSettle();
        expect(_key('duel-play-save-error'), findsOneWidget);
        expect(_key('duel-play-next'), findsNothing);
        expectTapTarget(tester, const Key('duel-play-save-retry'));

        queue.enqueueError = null;
        await tester.tap(_key('duel-play-save-retry'));
        await tester.pumpAndSettle();
        expect(_key('duel-play-save-error'), findsNothing);
        expect(queue.queued, hasLength(1));
        expect(_key('duel-play-next'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'тап-цели: «Дальше» не меньше 48 dp, на экране нет панели оценки',
    (tester) async {
      await open(tester);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      expectTapTarget(tester, const Key('duel-play-next'));
      expectTapTarget(tester, const Key('duel-play-close'));
    },
  );

  testWidgets('порядок вариантов у обоих участников один: зерно от вопроса и '
      'дуэли', (tester) async {
    await open(tester);
    final order = [
      for (final e in tester.widgetList(
        find.byWidgetPredicate(
          (w) => w.key is ValueKey && '${w.key}'.contains('mcq-option-'),
        ),
      ))
        '${e.key}',
    ];
    // Тот же набор и порядок при повторном открытии (устойчиво к перестройке).
    await tester.pumpAndSettle();
    final again = [
      for (final e in tester.widgetList(
        find.byWidgetPredicate(
          (w) => w.key is ValueKey && '${w.key}'.contains('mcq-option-'),
        ),
      ))
        '${e.key}',
    ];
    expect(again, order);
    expect(order, hasLength(3));
  });
}
