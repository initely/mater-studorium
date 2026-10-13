// Экран дуэли: «твой ход», «ждём», результат (T23, ТЗ M10, §8.4, AC10.1).
// Чужие ответы не запрашиваются и не показываются до завершения дуэли.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/data/duel_providers.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/duel/domain/duel_content.dart';
import 'package:mater_studorium/features/duel/domain/duel_result.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/duel_result_notifier.dart';
import 'package:mater_studorium/features/duel/presentation/isolate_name.dart';

import '../../../helpers/duel_fixtures.dart';
import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_duel_repository.dart';
import 'duel_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

final _ids = duelQuestionIds();

void main() {
  late FakeDuelRepository repo;
  late FakeDuelAnswerQueue queue;
  late FakeDuelContentSource content;
  late FakeDuelSeenStore seen;

  setUp(() {
    repo = FakeDuelRepository();
    queue = FakeDuelAnswerQueue();
    content = FakeDuelContentSource(content: contentOf());
    seen = FakeDuelSeenStore();
  });

  Future<void> open(
    WidgetTester tester, {
    FakeCatalogRepository? catalog,
    Duration? pollInterval,
    DateTime? now,
  }) => pumpDuelApp(
    tester,
    initial: '/duels/$kDuelId',
    repo: repo,
    queue: queue,
    content: content,
    seen: seen,
    pollInterval: pollInterval,
    now: now,
    catalog:
        catalog ??
        FakeCatalogRepository(local: [localDeck(kDuelDeckId, version: 2)]),
  );

  group('твой ход и ждём', () {
    testWidgets('твой ход: статус, соперник и кнопка «Играть»', (tester) async {
      repo.getResult = playDuel();
      await open(tester);
      expect(find.text('Твой ход'), findsOneWidget);
      expect(find.text('${isolateName('Алиса')} в дуэли'), findsOneWidget);
      expectTapTarget(tester, const Key('duel-play'));
      await tester.tap(_key('duel-play'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 1 из 5'), findsOneWidget);
    });

    testWidgets('колоды нет: вместо «Играть» карточка докачки', (tester) async {
      repo.getResult = playDuel();
      await open(tester, catalog: FakeCatalogRepository());
      expect(_key('duel-play'), findsNothing);
      expect(_key('duel-deck-missing'), findsOneWidget);
    });

    testWidgets('создатель до прихода соперника тоже может играть, код виден', (
      tester,
    ) async {
      repo.getResult = playDuel(
        isCreator: true,
        status: DuelStatus.open,
        otherJoined: false,
        otherName: null,
      );
      await open(tester);
      expect(find.text('Твой ход'), findsOneWidget);
      expect(_key('duel-play'), findsOneWidget);
      expect(_key('duel-code'), findsOneWidget);
    });

    testWidgets('я ответил на все, соперник нет: «Ждём Алису», без «Играть»', (
      tester,
    ) async {
      repo.getResult = playDuel(myDoneAt: duelNow);
      await open(tester);
      expect(find.text('Ждём ${isolateName('Алиса')}'), findsOneWidget);
      expect(_key('duel-waiting-body'), findsOneWidget);
      expect(_key('duel-play'), findsNothing);
      expect(_key('duel-sending'), findsNothing);
      // Чужие ответы не запрашиваются, пока дуэль не завершена (AC10.1).
      expect(repo.answersCalls.where((withOther) => withOther), isEmpty);
    });

    testWidgets(
      'создатель закончил, соперник не вошёл: «Ждём соперника» и код',
      (tester) async {
        repo.getResult = playDuel(
          isCreator: true,
          status: DuelStatus.open,
          otherJoined: false,
          otherName: null,
          myDoneAt: duelNow,
        );
        await open(tester);
        expect(find.text('Ждём соперника'), findsOneWidget);
        expect(_key('duel-code'), findsOneWidget);
        expect(_key('duel-play'), findsNothing);
      },
    );

    testWidgets('ответы ещё в очереди: «Ждём», «ответы отправляются»', (
      tester,
    ) async {
      repo.getResult = playDuel();
      for (final id in _ids) {
        queue.queued.add(
          DuelAnswerPayload(
            duelId: kDuelId,
            questionId: id,
            answer: const {
              'selected': ['a'],
            },
            isCorrect: true,
            durationMs: 1,
          ),
        );
      }
      await open(tester);
      expect(find.text('Ждём ${isolateName('Алиса')}'), findsOneWidget);
      expect(_key('duel-sending'), findsOneWidget);
      expect(_key('duel-play'), findsNothing);
    });

    testWidgets('часть ответов в очереди, часть на сервере: считается вместе', (
      tester,
    ) async {
      repo.getResult = playDuel();
      repo.answersResult = DuelAnswers(
        mine: [for (final id in _ids.take(3)) record(id)],
        other: const [],
      );
      for (final id in _ids.skip(3)) {
        queue.queued.add(
          DuelAnswerPayload(
            duelId: kDuelId,
            questionId: id,
            answer: const {
              'selected': ['a'],
            },
            isCorrect: true,
            durationMs: 1,
          ),
        );
      }
      await open(tester);
      expect(_key('duel-sending'), findsOneWidget);
    });

    testWidgets('после игры экран перечитывает состояние', (tester) async {
      repo.getResult = playDuel();
      await open(tester);
      final calls = repo.getCalls;
      await tester.tap(_key('duel-play'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.tap(_key('mcq-option-a'));
        await tester.pumpAndSettle();
        await tester.tap(_key('duel-play-next'));
        await tester.pumpAndSettle();
      }
      // Сервер уже знает про мои ответы.
      repo.getResult = playDuel(myDoneAt: duelNow);
      await tester.tap(_key('duel-play-back'));
      await tester.pumpAndSettle();
      expect(repo.getCalls, greaterThan(calls));
      expect(find.text('Ждём ${isolateName('Алиса')}'), findsOneWidget);
      expect(_key('duel-play'), findsNothing);
    });
  });

  group('обновление состояния', () {
    testWidgets('опрос по таймеру, пока ждём; завершённая и истёкшая не '
        'опрашиваются', (tester) async {
      repo.getResult = playDuel(myDoneAt: duelNow);
      await open(tester, pollInterval: const Duration(seconds: 30));
      expect(repo.getCalls, 1);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(repo.getCalls, 2);

      // Соперник закончил: следующий опрос приносит результат и опросы стоп.
      repo.getResult = playDuel(
        status: DuelStatus.finished,
        myDoneAt: duelNow,
        otherDoneAt: duelNow,
      );
      repo.answersResult = DuelAnswers(
        mine: [for (final id in _ids) record(id)],
        other: [for (final id in _ids) record(id, correct: false)],
      );
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(repo.getCalls, 3);
      expect(_key('duel-result-headline'), findsOneWidget);
      await tester.pump(const Duration(seconds: 90));
      await tester.pump();
      expect(repo.getCalls, 3, reason: 'у завершённой опроса нет');
    });

    testWidgets('без интервала опроса таймер не заводится', (tester) async {
      repo.getResult = playDuel(myDoneAt: duelNow);
      await open(tester);
      await tester.pump(const Duration(minutes: 5));
      expect(repo.getCalls, 1);
    });

    testWidgets('возврат в приложение перечитывает состояние', (tester) async {
      repo.getResult = playDuel(myDoneAt: duelNow);
      await open(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.getCalls, 2);
    });
  });

  group('результат', () {
    DuelAnswers answers({
      List<bool> mine = const [true, true, true, false, false],
      List<bool> other = const [true, false, false, false, false],
      int mineMs = 2000,
      int otherMs = 3000,
    }) => DuelAnswers(
      mine: [
        for (var i = 0; i < 5; i++)
          record(
            _ids[i],
            correct: mine[i],
            selected: mine[i] ? ['a'] : ['b'],
            ms: mineMs,
          ),
      ],
      other: [
        for (var i = 0; i < 5; i++)
          record(
            _ids[i],
            correct: other[i],
            selected: other[i] ? ['a'] : ['c'],
            ms: otherMs,
          ),
      ],
    );

    void finished({String? name = 'Алиса'}) {
      repo.getResult = playDuel(
        status: DuelStatus.finished,
        otherName: name,
        myDoneAt: duelNow,
        otherDoneAt: duelNow,
      );
    }

    testWidgets('счёт, время, ответы обоих, верный ответ и разбор', (
      tester,
    ) async {
      finished();
      repo.answersResult = answers();
      await open(tester);
      expect(find.text('Ты победил'), findsOneWidget);
      expect(find.text('Результат готов'), findsOneWidget);
      // Счёт и время: 3 из 5 за 10 с против 1 из 5 за 15 с.
      expect(
        find.descendant(
          of: _key('duel-result-mine'),
          matching: find.text('3 из 5'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('duel-result-mine'),
          matching: find.text('время 0:10'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('duel-result-other'),
          matching: find.text(isolateName('Алиса')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('duel-result-other'),
          matching: find.text('1 из 5'),
        ),
        findsOneWidget,
      );
      // Ответы запрошены у завершённой дуэли вместе с соперником.
      expect(repo.answersCalls, contains(true));

      // Вопрос 4: я выбрал «Второй» (неверно), он «Третий» (неверно), верный «Первый».
      final q4 = find.byKey(Key('duel-result-q-${_ids[3]}'));
      await tester.ensureVisible(q4);
      expect(
        find.descendant(of: q4, matching: find.text('Вопрос номер 4')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: q4,
          matching: find.textContaining(
            'Твой ответ: Второй · неверно · время 0:02',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: q4,
          matching: find.textContaining('Третий · неверно · время 0:03'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: q4,
          matching: find.textContaining('Верный ответ: Первый'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: q4,
          matching: find.textContaining('Разбор: Разбор 4'),
        ),
        findsOneWidget,
      );
      // Вопрос 1: у обоих верно.
      final q1 = find.byKey(Key('duel-result-q-${_ids[0]}'));
      expect(
        find.descendant(
          of: q1,
          matching: find.textContaining('Первый · верно'),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('поражение: победил соперник с именем', (tester) async {
      finished();
      repo.answersResult = answers(
        mine: [true, false, false, false, false],
        other: [true, true, false, false, false],
      );
      await open(tester);
      expect(find.text('Победил ${isolateName('Алиса')}'), findsOneWidget);
    });

    testWidgets('поровну верных: решает время; поровну всё — ничья', (
      tester,
    ) async {
      finished(name: null);
      repo.answersResult = answers(
        mine: [true, true, false, false, false],
        other: [true, true, false, false, false],
        mineMs: 1000,
        otherMs: 1000,
      );
      await open(tester);
      expect(find.text('Ничья'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('duel-result-other'),
          matching: find.text('Соперник'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'вопроса нет на устройстве: ответы видны, текстов вопроса нет',
      (tester) async {
        finished();
        repo.answersResult = answers();
        content.content = contentOf(missing: {_ids[1]});
        await open(tester);
        final q2 = find.byKey(Key('duel-result-q-${_ids[1]}'));
        await tester.ensureVisible(q2);
        expect(
          find.descendant(
            of: q2,
            matching: _key('duel-result-unavailable-${_ids[1]}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: q2, matching: find.textContaining('верно')),
          findsWidgets,
        );
        expect(_key('duel-result-correct-${_ids[1]}'), findsNothing);
      },
    );

    testWidgets('колоды нет: счёт и верность есть, тексты — нет, без падения', (
      tester,
    ) async {
      finished();
      repo.answersResult = answers();
      content.content = null;
      await open(tester);
      expect(_key('duel-result-deck-missing'), findsOneWidget);
      expect(find.text('Ты победил'), findsOneWidget);
      expect(find.textContaining('Верный ответ'), findsNothing);
    });

    testWidgets('нет разбора у знания: строки «Разбор» нет, остальное есть', (
      tester,
    ) async {
      finished();
      repo.answersResult = answers();
      final base = contentOf();
      final q0 = base.questions[_ids[0]]!;
      content.content = DuelContent(
        deckVersion: 2,
        questions: {
          ...base.questions,
          _ids[0]: DuelQuestionContent(
            question: q0.question,
            item: q0.item.copyWith(explanationShort: '   '),
          ),
        },
      );
      await open(tester);
      expect(_key('duel-result-explanation-${_ids[0]}'), findsNothing);
      expect(_key('duel-result-explanation-${_ids[1]}'), findsOneWidget);
      expect(_key('duel-result-correct-${_ids[0]}'), findsOneWidget);
    });

    testWidgets('пропущенный вопрос: подпись «был недоступен», неверно', (
      tester,
    ) async {
      finished();
      repo.answersResult = DuelAnswers(
        mine: [
          for (var i = 0; i < 5; i++)
            i == 2
                ? DuelAnswerRecord(
                    questionId: _ids[i],
                    answer: const {'skipped': true},
                    isCorrect: false,
                    durationMs: 0,
                  )
                : record(_ids[i]),
        ],
        other: [for (final id in _ids) record(id)],
      );
      await open(tester);
      final q3 = find.byKey(Key('duel-result-q-${_ids[2]}'));
      await tester.ensureVisible(q3);
      expect(
        find.descendant(
          of: q3,
          matching: find.textContaining(
            'вопрос был недоступен, засчитан неверным',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ответа соперника нет: «нет ответа»', (tester) async {
      finished();
      repo.answersResult = DuelAnswers(
        mine: [for (final id in _ids) record(id)],
        other: const [],
      );
      await open(tester);
      expect(find.textContaining('нет ответа'), findsWidgets);
    });

    testWidgets('ответ в чужом виде не роняет экран', (tester) async {
      finished();
      repo.answersResult = DuelAnswers(
        mine: [for (final id in _ids) record(id)],
        other: [
          for (final id in _ids)
            DuelAnswerRecord(
              questionId: id,
              answer: const {'странное': 1},
              isCorrect: true,
              durationMs: 10,
            ),
        ],
      );
      await open(tester);
      expect(find.textContaining('ответ в неизвестном виде'), findsWidgets);
    });

    testWidgets('результат открыт: карточка на главном больше не нужна', (
      tester,
    ) async {
      finished();
      repo.answersResult = answers();
      await open(tester);
      expect(seen.seen, {kDuelId});
    });

    testWidgets('ошибка загрузки ответов: сообщение и повтор', (tester) async {
      finished();
      repo.answersError = offline;
      await open(tester);
      expect(_key('duel-result-error'), findsOneWidget);
      expectTapTarget(tester, const Key('duel-result-retry'));
      repo
        ..answersError = null
        ..answersResult = answers();
      await tester.ensureVisible(_key('duel-result-retry'));
      await tester.tap(_key('duel-result-retry'));
      await tester.pumpAndSettle();
      expect(find.text('Ты победил'), findsOneWidget);
    });

    testWidgets(
      'не удалось запомнить «просмотрено»: результат всё равно виден',
      (tester) async {
        finished();
        repo.answersResult = answers();
        seen.error = const LocalStorageError('диск');
        await open(tester);
        expect(find.text('Ты победил'), findsOneWidget);
      },
    );

    testWidgets('семантика счёта: одной подписью на участника', (tester) async {
      finished();
      repo.answersResult = answers();
      await open(tester);
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Ты: верных 3 из 5, время 0:10'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('до завершения чужие ответы не показываются (AC10.1)', () {
    testWidgets('я закончил, соперник нет: чужие ответы не запрашиваются '
        'и не показаны, даже если сервер их отдаёт', (tester) async {
      repo.getResult = playDuel(myDoneAt: duelNow, otherDoneAt: null);
      repo.answersResult = DuelAnswers(
        mine: [for (final id in _ids) record(id)],
        other: [for (final id in _ids) record(id, correct: false)],
      );
      await open(tester);
      expect(_key('duel-result-headline'), findsNothing);
      expect(_key('duel-result-other'), findsNothing);
      expect(repo.answersCalls.contains(true), isFalse);
    });

    testWidgets('играю: чужие ответы не запрашиваются', (tester) async {
      repo.getResult = playDuel();
      await pumpDuelApp(
        tester,
        initial: '/duels/$kDuelId/play',
        repo: repo,
        queue: queue,
        content: content,
        catalog: FakeCatalogRepository(
          local: [localDeck(kDuelDeckId, version: 2)],
        ),
      );
      expect(find.text('Вопрос 1 из 5'), findsOneWidget);
      expect(repo.answersCalls.contains(true), isFalse);
    });
  });

  group('duelResultProvider: чужие ответы только у завершённой дуэли', () {
    Future<DuelResultData?> resultFor() async {
      final container = ProviderContainer(
        overrides: [
          duelRepositoryProvider.overrideWithValue(repo),
          duelContentSourceProvider.overrideWithValue(content),
          duelSeenStoreProvider.overrideWithValue(seen),
        ],
      );
      addTearDown(container.dispose);
      return container.read(duelResultProvider(kDuelId).future);
    }

    for (final (name, duel) in [
      ('идёт игра', playDuel()),
      ('я закончил, соперник нет', playDuel(myDoneAt: duelNow)),
      ('соперник закончил, я нет', playDuel(otherDoneAt: duelNow)),
      ('истекла', playDuel(status: DuelStatus.expired, myDoneAt: duelNow)),
    ]) {
      test(
        '$name: результата нет, ответы соперника не запрашиваются',
        () async {
          repo
            ..getResult = duel
            ..answersResult = DuelAnswers(
              mine: [for (final id in _ids) record(id)],
              other: [for (final id in _ids) record(id)],
            );
          expect(await resultFor(), isNull);
          expect(repo.answersCalls, isEmpty);
          expect(seen.seen, isEmpty);
        },
      );
    }

    test('завершена: результат есть, ответы соперника запрошены', () async {
      repo
        ..getResult = playDuel(
          status: DuelStatus.finished,
          myDoneAt: duelNow,
          otherDoneAt: duelNow,
        )
        ..answersResult = DuelAnswers(
          mine: [for (final id in _ids) record(id)],
          other: [for (final id in _ids) record(id, correct: false)],
        );
      final data = await resultFor();
      expect(data!.result.outcome, DuelOutcome.won);
      expect(repo.answersCalls, [true]);
    });
  });
}
