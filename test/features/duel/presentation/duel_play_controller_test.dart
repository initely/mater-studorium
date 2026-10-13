// DuelPlayController (T23, ADR-16, ADR-36): сценарии, секундомер на фейковых
// часах, повторный ответ, недоступные вопросы, офлайн.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/features/duel/data/duel_providers.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/duel_play_controller.dart';
import 'package:mater_studorium/features/questions/question_result.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

import '../../../helpers/duel_fixtures.dart';
import '../../../helpers/fake_duel_repository.dart';

QuestionResult _right([List<String> selected = const ['a']]) => QuestionResult(
  outcome: AnswerOutcome.autoCorrect,
  answer: {'selected': selected},
);
QuestionResult _wrong() => const QuestionResult(
  outcome: AnswerOutcome.autoIncorrect,
  answer: {
    'selected': ['b'],
  },
);

void main() {
  late FakeDuelRepository repo;
  late FakeDuelAnswerQueue queue;
  late FakeDuelContentSource content;
  late DateTime now;
  late ProviderContainer container;

  setUp(() {
    now = duelNow;
    repo = FakeDuelRepository()..getResult = playDuel();
    queue = FakeDuelAnswerQueue();
    content = FakeDuelContentSource(content: contentOf());
    container = ProviderContainer(
      overrides: [
        duelRepositoryProvider.overrideWithValue(repo),
        duelAnswerQueueProvider.overrideWithValue(queue),
        duelContentSourceProvider.overrideWithValue(content),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(duelPlayProvider(kDuelId), (_, _) {});
  });

  DuelPlayController ctl() =>
      container.read(duelPlayProvider(kDuelId).notifier);
  DuelPlayState st() => container.read(duelPlayProvider(kDuelId));

  Future<void> answer(QuestionResult r, {int afterMs = 1000}) async {
    now = now.add(Duration(milliseconds: afterMs));
    await ctl().onAnswered(r);
  }

  test(
    'полная игра: пять ответов по порядку набора, время и верность',
    () async {
      await ctl().load();
      expect(st().phase, DuelPlayPhase.playing);
      expect(st().index, 0);
      expect(st().shownAt, duelNow);

      final results = [_right(), _wrong(), _right(), _right(), _wrong()];
      for (var i = 0; i < 5; i++) {
        expect(st().index, i);
        expect(st().current!.questionId, duelQuestionIds()[i]);
        await answer(results[i], afterMs: 1000 * (i + 1));
        expect(st().currentAnswered, isTrue);
        ctl().next();
      }
      expect(st().phase, DuelPlayPhase.done);
      expect([for (final a in queue.queued) a.questionId], duelQuestionIds());
      expect(
        [for (final a in queue.queued) a.isCorrect],
        [true, false, true, true, false],
      );
      expect(
        [for (final a in queue.queued) a.durationMs],
        [1000, 2000, 3000, 4000, 5000],
      );
      expect(queue.queued.first.duelId, kDuelId);
      expect(queue.queued[1].answer, {
        'selected': ['b'],
      });
    },
  );

  test('секундомер идёт от показа вопроса: время считается по часам, а не '
      'по числу кадров', () async {
    await ctl().load();
    now = now.add(const Duration(seconds: 90));
    await ctl().onAnswered(_right());
    expect(queue.queued.single.durationMs, 90000);
    expect(st().lastDurationMs, 90000);
    // Следующий вопрос: отсчёт с нуля от момента показа.
    ctl().next();
    expect(st().shownAt, now);
    now = now.add(const Duration(milliseconds: 250));
    await ctl().onAnswered(_right());
    expect(queue.queued.last.durationMs, 250);
  });

  test('часы ушли назад или время огромное: 0 и не больше суток', () async {
    await ctl().load();
    now = now.subtract(const Duration(minutes: 5));
    await ctl().onAnswered(_right());
    expect(queue.queued.single.durationMs, 0);
    ctl().next();
    now = now.add(const Duration(days: 3));
    await ctl().onAnswered(_right());
    expect(queue.queued.last.durationMs, 86400000);
  });

  test('повторный ответ на тот же вопрос игнорируется', () async {
    await ctl().load();
    await answer(_right());
    await ctl().onAnswered(_wrong());
    await ctl().onAnswered(_wrong());
    expect(queue.queued, hasLength(1));
    expect(queue.queued.single.isCorrect, isTrue, reason: 'первый побеждает');
  });

  test(
    'контроллер сам не шлёт второй ответ, даже если очередь не защищает',
    () async {
      final naive = FakeDuelAnswerQueue(dedupe: false);
      container.dispose();
      container = ProviderContainer(
        overrides: [
          duelRepositoryProvider.overrideWithValue(repo),
          duelAnswerQueueProvider.overrideWithValue(naive),
          duelContentSourceProvider.overrideWithValue(content),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      container.listen(duelPlayProvider(kDuelId), (_, _) {});
      await ctl().load();
      now = now.add(const Duration(seconds: 1));
      await ctl().onAnswered(_right());
      await ctl().onAnswered(_wrong());
      await Future.wait([
        ctl().onAnswered(_right()),
        ctl().onAnswered(_right()),
      ]);
      expect(naive.queued, hasLength(1));
    },
  );

  test('двойной вызов одновременно пишет один ответ', () async {
    await ctl().load();
    now = now.add(const Duration(seconds: 1));
    await Future.wait([ctl().onAnswered(_right()), ctl().onAnswered(_right())]);
    expect(queue.queued, hasLength(1));
    expect(queue.enqueueCalls, 1);
  });

  test('next() до ответа не пропускает вопрос', () async {
    await ctl().load();
    ctl().next();
    expect(st().index, 0);
    expect(st().currentAnswered, isFalse);
  });

  group('возобновление', () {
    test(
      'ответы в очереди пропускаются: игра с первого неотвеченного',
      () async {
        queue.queued
          ..add(_payload(0))
          ..add(_payload(1));
        await ctl().load();
        expect(st().phase, DuelPlayPhase.playing);
        expect(st().index, 2);
        expect(st().answered, {duelQuestionIds()[0], duelQuestionIds()[1]});
      },
    );

    test(
      'ответы уже на сервере пропускаются, даже если очередь пуста',
      () async {
        repo.answersResult = DuelAnswers(
          mine: [for (final id in duelQuestionIds().take(3)) record(id)],
          other: const [],
        );
        await ctl().load();
        expect(st().index, 3);
        expect(repo.answersCalls, [false], reason: 'только свои');
      },
    );

    test('сервер говорит, что я закончил: игры нет, done', () async {
      repo.getResult = playDuel(myDoneAt: duelNow);
      await ctl().load();
      expect(st().phase, DuelPlayPhase.done);
      expect(queue.queued, isEmpty);
    });

    test('все пять в очереди: done, ответить повторно нельзя', () async {
      for (var i = 0; i < 5; i++) {
        queue.queued.add(_payload(i));
      }
      await ctl().load();
      expect(st().phase, DuelPlayPhase.done);
      await ctl().onAnswered(_right());
      expect(queue.queued, hasLength(5));
    });

    test('нет сети: берётся очередь, игра идёт', () async {
      queue.queued.add(_payload(0));
      repo.answersError = offline;
      await ctl().load();
      expect(st().phase, DuelPlayPhase.playing);
      expect(st().index, 1);
    });

    test(
      'заново открыли экран на втором вопросе: первый не повторяется',
      () async {
        await ctl().load();
        await answer(_right());
        ctl().next();
        expect(st().index, 1);
        // Выход из экрана и новый вход: новый контроллер, очередь та же.
        container.invalidate(duelPlayProvider(kDuelId));
        container.listen(duelPlayProvider(kDuelId), (_, _) {});
        await ctl().load();
        expect(st().index, 1);
        expect(st().answered, {duelQuestionIds()[0]});
      },
    );
  });

  group('сохранение ответа', () {
    test(
      'ошибка очереди: saveFailed, вопрос остаётся, повтор сохраняет',
      () async {
        await ctl().load();
        queue.enqueueError = const LocalStorageError('диск');
        await answer(_right(), afterMs: 2000);
        expect(st().saveFailed, isTrue);
        expect(st().currentAnswered, isFalse);
        expect(st().answered, isEmpty);

        queue.enqueueError = null;
        now = now.add(const Duration(minutes: 1));
        await ctl().retrySave();
        expect(st().saveFailed, isFalse);
        expect(st().currentAnswered, isTrue);
        expect(
          queue.queued.single.durationMs,
          2000,
          reason: 'время ответа, а не повтора',
        );
      },
    );

    test(
      'ответ уже в очереди (повтор из другого экземпляра): принят',
      () async {
        await ctl().load();
        queue.queued.add(_payload(0));
        await answer(_right());
        expect(st().currentAnswered, isTrue);
        expect(queue.queued, hasLength(1));
      },
    );
  });

  group('недоступные вопросы (ADR-36, п. 12 ADR-35)', () {
    test('вопроса нет в локальной колоде: blocked, играть нельзя', () async {
      content.content = contentOf(missing: {duelQuestionIds()[3]});
      await ctl().load();
      expect(st().phase, DuelPlayPhase.blocked);
      expect(st().unavailableCount, 1);
      expect(st().deckMissing, isFalse);
      await ctl().onAnswered(_right());
      expect(queue.queued, isEmpty);
    });

    test(
      '«Сыграть без них»: пропущенный засчитан неверным, остальные играются',
      () async {
        content.content = contentOf(missing: {duelQuestionIds()[1]});
        await ctl().load();
        await ctl().playWithoutUnavailable();
        expect(st().phase, DuelPlayPhase.playing);
        expect(st().index, 0);
        final skipped = queue.queued.single;
        expect(skipped.questionId, duelQuestionIds()[1]);
        expect(skipped.isCorrect, isFalse);
        expect(skipped.durationMs, 0);
        expect(skipped.answer, {'skipped': true});

        // Дальше: 0, 2, 3, 4 (вопрос 1 пропущен).
        final order = <int>[];
        while (st().phase == DuelPlayPhase.playing) {
          order.add(st().index);
          await answer(_right());
          ctl().next();
        }
        expect(order, [0, 2, 3, 4]);
        expect(st().phase, DuelPlayPhase.done);
        expect(queue.queued, hasLength(5));
      },
    );

    test(
      'все пять недоступны: blocked, «без них» — все неверные, done',
      () async {
        content.content = contentOf(n: 0);
        await ctl().load();
        expect(st().unavailableCount, 5);
        await ctl().playWithoutUnavailable();
        expect(st().phase, DuelPlayPhase.done);
        expect(queue.queued, hasLength(5));
        expect(queue.queued.every((a) => !a.isCorrect), isTrue);
      },
    );

    test('колоды нет на устройстве: blocked с deckMissing', () async {
      content.content = null;
      await ctl().load();
      expect(st().phase, DuelPlayPhase.blocked);
      expect(st().deckMissing, isTrue);
      await ctl().playWithoutUnavailable();
      expect(queue.queued, isEmpty, reason: 'без колоды пропускать нечего');
    });

    test('уже отвеченный недоступный вопрос не блокирует', () async {
      content.content = contentOf(missing: {duelQuestionIds()[0]});
      queue.queued.add(_payload(0));
      await ctl().load();
      expect(st().phase, DuelPlayPhase.playing);
      expect(st().index, 1);
    });

    test('после докачки колоды перезагрузка снимает блок', () async {
      content.content = contentOf(missing: {duelQuestionIds()[0]});
      await ctl().load();
      expect(st().phase, DuelPlayPhase.blocked);
      content.content = contentOf();
      await ctl().load();
      expect(st().phase, DuelPlayPhase.playing);
    });
  });

  group('дуэль закрыта, нет или ошибка', () {
    test('дуэли нет: notFound', () async {
      repo.getResult = null;
      await ctl().load();
      expect(st().phase, DuelPlayPhase.notFound);
    });

    test('завершённая: closed, вопросы не читаются', () async {
      repo.getResult = playDuel(
        status: DuelStatus.finished,
        myDoneAt: duelNow,
        otherDoneAt: duelNow,
      );
      await ctl().load();
      expect(st().phase, DuelPlayPhase.closed);
      expect(content.loads, 0);
    });

    test('срок вышел по часам клиента: closed', () async {
      now = duelNow.add(const Duration(hours: 73));
      await ctl().load();
      expect(st().phase, DuelPlayPhase.closed);
    });

    test('нет сети при чтении дуэли: error, повтор работает', () async {
      repo.getError = offline;
      await ctl().load();
      expect(st().phase, DuelPlayPhase.error);
      expect(st().error, isA<NetworkError>());
      repo.getError = null;
      await ctl().load();
      expect(st().phase, DuelPlayPhase.playing);
    });

    test('ошибка локальной колоды: error', () async {
      content.error = const LocalStorageError('диск');
      await ctl().load();
      expect(st().phase, DuelPlayPhase.error);
    });
  });

  test('ответы дуэли идут только в очередь дуэли (не в сессию)', () async {
    // Контроллер зависит лишь от репозитория дуэли, очереди, источника
    // вопросов и часов: других провайдеров (сессия, FSRS) в контейнере нет,
    // и игра проходит. Запись в FSRS доказана на drift в памяти:
    // duel_play_drift_test.dart.
    await ctl().load();
    for (var i = 0; i < 5; i++) {
      await answer(_right());
      ctl().next();
    }
    expect(st().phase, DuelPlayPhase.done);
  });
}

DuelAnswerPayload _payload(int i) => DuelAnswerPayload(
  duelId: kDuelId,
  questionId: duelQuestionIds()[i],
  answer: const {
    'selected': ['a'],
  },
  isCorrect: true,
  durationMs: 100,
);
