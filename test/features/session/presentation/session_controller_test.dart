import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/db/database_providers.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/data/sync_providers.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/domain/local_item.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/domain/item_content.dart';
import 'package:mater_studorium/features/session/domain/review_log.dart';
import 'package:mater_studorium/features/session/domain/session_repository.dart';
import 'package:mater_studorium/features/session/domain/session_settings.dart';
import 'package:mater_studorium/features/session/domain/session_state.dart';
import 'package:mater_studorium/features/session/presentation/session_controller.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/session_db_fixtures.dart';

final start = DateTime.utc(2026, 10, 11, 12);

class _Clock {
  DateTime now = start;
}

/// Контейнер на реальной БД; время двигается через `h.now = ...`.
class Harness {
  factory Harness(
    AppDatabase db, {
    List<Override> overrides = const [],
    SessionSettings settings = const SessionSettings(),
    String Function()? ids,
  }) {
    final clock = _Clock();
    return Harness._(
      db,
      clock,
      ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sessionUserIdProvider.overrideWithValue(() => sessionUser),
          clockProvider.overrideWithValue(() => clock.now),
          randomProvider.overrideWithValue(math.Random(1)),
          uuidGeneratorProvider.overrideWithValue(
            ids ?? () => 'id-${_counter++}',
          ),
          sessionSettingsProvider.overrideWithValue(settings),
          ...overrides,
        ],
      ),
    );
  }

  Harness._(this.db, this._clock, this.container) {
    container.listen(sessionControllerProvider, (_, _) {});
  }

  final AppDatabase db;
  final ProviderContainer container;
  final _Clock _clock;
  static var _counter = 0;

  DateTime get now => _clock.now;
  set now(DateTime value) => _clock.now = value;

  SessionController get controller =>
      container.read(sessionControllerProvider.notifier);
  SessionState get state => container.read(sessionControllerProvider);

  Future<void> submit({
    Rating rating = Rating.good,
    GradeSource source = GradeSource.auto,
    int durationMs = 1500,
    String? answerText,
    double? llmScore,
  }) => controller.submit(
    rating: rating,
    gradeSource: source,
    durationMs: durationMs,
    answerText: answerText,
    llmScore: llmScore,
  );
}

Future<AppDatabase> dbWithBigDeck({int n = 6}) async {
  final db = memoryDb();
  await db.decksDao.replaceDeck(
    bigDeck('big', n, version: 4),
    downloadedAt: t0,
  );
  return db;
}

void main() {
  setUp(() => Harness._counter = 0);

  group('старт', () {
    test('строит очередь и начинает сессию с первого вопроса', () async {
      final h = Harness(await dbWithBigDeck());
      addTearDown(h.container.dispose);
      expect(h.state.status, SessionStatus.idle);
      expect(h.state.current, isNull);
      expect(h.state.remaining(start), kSessionDuration);

      await h.controller.start();

      expect(h.state.status, SessionStatus.running);
      expect(h.state.queue!.items, hasLength(6));
      expect(h.state.current!.item.id, 'big.1');
      expect(h.state.index, 0);
      expect(h.state.startedAt, start);
      expect(h.state.deadline, start.add(const Duration(minutes: 5)));
      expect(h.state.answers, isEmpty);
    });

    test('пустая очередь: сессия сразу finished, причина в очереди', () async {
      final h = Harness(memoryDb());
      addTearDown(h.container.dispose);

      await h.controller.start();

      expect(h.state.status, SessionStatus.finished);
      expect(h.state.queue!.isEmpty, isTrue);
      expect(h.state.current, isNull);
    });

    test('extraNew и настройки доходят до построителя', () async {
      final h = Harness(
        await dbWithBigDeck(n: 12),
        settings: const SessionSettings(newPerDay: 2, sessionSize: 5),
      );
      addTearDown(h.container.dispose);

      await h.controller.start(extraNew: 2);

      expect(h.state.queue!.items, hasLength(4));
    });

    test('контейнер закрыт, пока строилась очередь: без ошибок', () async {
      final db = await dbWithBigDeck();
      final h = Harness(db);

      final started = h.controller.start();
      h.container.dispose();

      await started;
    });
  });

  group('submit', () {
    test('пишет лог и состояние FSRS, двигает очередь', () async {
      final db = await dbWithBigDeck();
      final h = Harness(db);
      addTearDown(h.container.dispose);
      await h.controller.start();
      final first = h.state.current!;
      h.now = start.add(const Duration(seconds: 20));

      await h.submit(
        rating: Rating.hard,
        source: GradeSource.override,
        durationMs: 4200,
        answerText: 'мой ответ',
        llmScore: 0.5,
      );

      final logs = await db.select(db.reviewLogs).get();
      expect(logs, hasLength(1));
      final log = logs.single;
      expect(log.id, 'id-0');
      expect(log.userId, sessionUser);
      expect(log.deckId, 'big');
      expect(log.deckVersion, 4);
      expect(log.itemId, 'big.1');
      expect(log.questionId, first.question.id);
      expect(log.questionType, first.question.type.wire);
      expect(log.rating, Rating.hard.code);
      expect(log.gradeSource, 'override');
      expect(log.llmScore, 0.5);
      expect(log.answerText, 'мой ответ');
      expect(log.durationMs, 4200);
      expect(log.reviewedAt.toUtc(), h.now);

      final saved = (await db.reviewDao.getState(sessionUser, 'big.1'))!;
      expect(saved.state, isNot(SrsState.newCard));
      expect(saved.reps, 1);
      expect(saved.lastReview, h.now);
      expect(saved.lastQuestionId, first.question.id);
      expect(saved.due.isAfter(h.now), isTrue);
      final row = await db.select(db.userItemStates).getSingle();
      expect(row.dirty, isTrue);

      expect(h.state.index, 1);
      expect(h.state.current!.item.id, 'big.2');
      expect(h.state.status, SessionStatus.running);
      expect(h.state.answers.map((a) => a.id), ['id-0']);
      expect(h.state.answers.single.rating, Rating.hard);
    });

    test('повторение: состояние считается планировщиком от прежнего', () async {
      final db = await dbWithBigDeck(n: 1);
      final due = start.subtract(const Duration(days: 3));
      await db.reviewDao.recordReview(
        userId: sessionUser,
        log: logFor('big.1', id: 'old').copyWith(deckId: 'big'),
        state: ItemState(
          itemId: 'big.1',
          deckId: 'big',
          due: due,
          stability: 4,
          difficulty: 5,
          elapsedDays: 4,
          scheduledDays: 4,
          reps: 2,
          lapses: 0,
          state: SrsState.review,
          lastReview: due.subtract(const Duration(days: 4)),
          updatedAt: due,
        ),
      );
      final h = Harness(db);
      addTearDown(h.container.dispose);
      await h.controller.start();
      expect(h.state.current!.isNew, isFalse);

      await h.submit(rating: Rating.again);

      final saved = (await db.reviewDao.getState(sessionUser, 'big.1'))!;
      expect(saved.reps, 3);
      expect(saved.lapses, 1, reason: 'Again из review даёт lapse');
      expect(saved.state, SrsState.relearning);
    });

    test('очередь закончилась: finished, ответ записан', () async {
      final h = Harness(await dbWithBigDeck(n: 2));
      addTearDown(h.container.dispose);
      await h.controller.start();

      await h.submit();
      expect(h.state.status, SessionStatus.running);
      await h.submit();

      expect(h.state.status, SessionStatus.finished);
      expect(h.state.current, isNull);
      expect(h.state.answers, hasLength(2));
      expect(await h.db.select(h.db.reviewLogs).get(), hasLength(2));
    });

    test('время вышло: начатый вопрос дописывается, потом finished', () async {
      final h = Harness(await dbWithBigDeck());
      addTearDown(h.container.dispose);
      await h.controller.start();
      await h.submit();

      // Время истекло, пока пользователь был на втором вопросе.
      h.now = start.add(const Duration(minutes: 5, seconds: 1));
      expect(h.state.remaining(h.now), Duration.zero);
      expect(h.state.status, SessionStatus.running);
      expect(h.state.current!.item.id, 'big.2');

      await h.submit();

      expect(h.state.status, SessionStatus.finished);
      expect(h.state.answers, hasLength(2));
      expect(await h.db.select(h.db.reviewLogs).get(), hasLength(2));
    });

    test('таймер ровно на 5:00: ответ принят, затем finished', () async {
      final h = Harness(await dbWithBigDeck());
      addTearDown(h.container.dispose);
      await h.controller.start();

      h.now = start.add(kSessionDuration);
      await h.submit();

      expect(h.state.status, SessionStatus.finished);
    });

    test('за секунду до конца сессия продолжается', () async {
      final h = Harness(await dbWithBigDeck());
      addTearDown(h.container.dispose);
      await h.controller.start();

      h.now = start.add(kSessionDuration - const Duration(seconds: 1));
      await h.submit();

      expect(h.state.status, SessionStatus.running);
      expect(h.state.remaining(h.now), const Duration(seconds: 1));
    });

    test('вне сессии submit ничего не делает', () async {
      final h = Harness(await dbWithBigDeck(n: 1));
      addTearDown(h.container.dispose);

      await h.submit(); // idle
      expect(await h.db.select(h.db.reviewLogs).get(), isEmpty);

      await h.controller.start();
      await h.submit();
      await h.submit(); // finished
      expect(await h.db.select(h.db.reviewLogs).get(), hasLength(1));
    });

    test(
      'двойной тап: второй submit игнорируется, знание повторено один раз',
      () async {
        final h = Harness(await dbWithBigDeck());
        addTearDown(h.container.dispose);
        await h.controller.start();

        await Future.wait([h.submit(), h.submit()]);

        expect(await h.db.select(h.db.reviewLogs).get(), hasLength(1));
        expect(h.state.index, 1);
      },
    );

    test(
      'ошибка записи: LocalStorageError, вопрос остаётся, можно повторить',
      () async {
        final db = await dbWithBigDeck();
        final ids = ['dup', 'dup', 'fresh'].iterator;
        final h = Harness(
          db,
          ids: () {
            ids.moveNext();
            return ids.current;
          },
        );
        addTearDown(h.container.dispose);
        await h.controller.start();
        await h.submit(); // id 'dup' записан

        await expectLater(h.submit(), throwsA(isA<LocalStorageError>()));
        expect(h.state.index, 1, reason: 'вопрос не сдвинулся');
        expect(h.state.answers, hasLength(1));
        expect(await db.reviewDao.getState(sessionUser, 'big.2'), isNull);

        await h.submit(); // повтор с новым id
        expect(h.state.index, 2);
        expect(await db.select(db.reviewLogs).get(), hasLength(2));
      },
    );
  });

  group('finish', () {
    test(
      'завершает идущую сессию; в других состояниях ничего не делает',
      () async {
        final h = Harness(await dbWithBigDeck());
        addTearDown(h.container.dispose);

        h.controller.finish();
        expect(h.state.status, SessionStatus.idle);

        await h.controller.start();
        await h.submit();
        h.controller.finish();
        expect(h.state.status, SessionStatus.finished);
        expect(h.state.answers, hasLength(1));

        h.controller.finish();
        expect(h.state.status, SessionStatus.finished);
      },
    );

    test(
      'finish во время записи ответа: ответ сохранён, сессия finished',
      () async {
        final db = await dbWithBigDeck();
        final gate = Completer<void>();
        final h = Harness(
          db,
          overrides: [
            sessionRepositoryProvider.overrideWithValue(
              _GatedRepository(repositoryFor(db), gate.future),
            ),
          ],
        );
        addTearDown(h.container.dispose);
        await h.controller.start();

        final submitting = h.submit();
        h.controller.finish();
        gate.complete();
        await submitting;

        expect(h.state.status, SessionStatus.finished);
        expect(h.state.answers, hasLength(1));
        expect(await db.select(db.reviewLogs).get(), hasLength(1));
      },
    );

    test(
      'контейнер закрыт во время записи ответа: без ошибок, ответ записан',
      () async {
        final db = await dbWithBigDeck();
        final gate = Completer<void>();
        final h = Harness(
          db,
          overrides: [
            sessionRepositoryProvider.overrideWithValue(
              _GatedRepository(repositoryFor(db), gate.future),
            ),
          ],
        );
        await h.controller.start();

        final submitting = h.submit();
        h.container.dispose();
        gate.complete();
        await submitting;

        expect(await db.select(db.reviewLogs).get(), hasLength(1));
      },
    );
  });

  group('синхронизация (T17)', () {
    test('конец сессии (очередь кончилась или finish) просит синк; во время '
        'сессии — нет', () async {
      var requests = 0;
      final h = Harness(
        await dbWithBigDeck(n: 2),
        overrides: [syncRequestProvider.overrideWithValue(() => requests++)],
      );
      addTearDown(h.container.dispose);
      await h.controller.start();
      await h.submit();
      expect(requests, 0);
      await h.submit();
      expect(h.state.status, SessionStatus.finished);
      expect(requests, 1);

      final h2 = Harness(
        await dbWithBigDeck(),
        overrides: [syncRequestProvider.overrideWithValue(() => requests++)],
      );
      addTearDown(h2.container.dispose);
      await h2.controller.start();
      await h2.submit();
      h2.controller.finish();
      expect(requests, 2);
      h2.controller.finish(); // уже finished: повторно не просит
      expect(requests, 2);
    });
  });

  group('AC3.2: сессию прервали', () {
    test('уже данные ответы сохранены, FSRS обновлён, при перезапуске очередь продолжается', () async {
      final db = await dbWithBigDeck(n: 5);
      final first = Harness(db);
      await first.controller.start();
      first.now = start.add(const Duration(seconds: 30));
      await first.submit(rating: Rating.good);
      first.now = start.add(const Duration(seconds: 50));
      await first.submit(rating: Rating.easy);
      final answeredStates = {
        for (final id in ['big.1', 'big.2'])
          id: (await db.reviewDao.getState(sessionUser, id))!,
      };
      // Закрыли приложение посреди третьего вопроса: контейнер выброшен.
      first.container.dispose();

      // Новый запуск на той же БД.
      expect(await db.select(db.reviewLogs).get(), hasLength(2));
      for (final MapEntry(key: id, value: s) in answeredStates.entries) {
        expect((await db.reviewDao.getState(sessionUser, id)), s);
        expect(s.reps, 1);
        expect(s.state, isNot(SrsState.newCard));
        expect(s.due.isAfter(start), isTrue);
      }
      final second = Harness(db);
      addTearDown(second.container.dispose);
      second.now = start.add(const Duration(minutes: 3));
      await second.controller.start();

      // Отвеченные знания не вернулись (не просрочены), остались три
      // неотвеченных новых; лимит дня 10 уже учитывает две отвеченные.
      expect(second.state.queue!.items.map((i) => i.item.id), [
        'big.3',
        'big.4',
        'big.5',
      ]);
      expect(second.state.queue!.dueCount, 0);
    });
  });

  group('SessionState', () {
    test('remaining не уходит в минус; copyWith меняет только своё', () {
      final s = SessionState(
        status: SessionStatus.running,
        startedAt: start,
        index: 2,
      );

      expect(s.remaining(start), kSessionDuration);
      expect(
        s.remaining(start.add(const Duration(minutes: 2))),
        const Duration(minutes: 3),
      );
      expect(s.remaining(start.add(const Duration(hours: 1))), Duration.zero);
      final c = s.copyWith(status: SessionStatus.finished);
      expect(c.status, SessionStatus.finished);
      expect(c.index, 2);
      expect(c.startedAt, start);
      expect(c.copyWith(index: 5).index, 5);
      expect(c.copyWith(answers: const []).answers, isEmpty);
    });
  });
}

/// Репозиторий, у которого запись ответа ждёт [gate].
class _GatedRepository implements SessionRepository {
  _GatedRepository(this._inner, this._gate);

  final SessionRepository _inner;
  final Future<void> _gate;

  @override
  Future<void> recordReview({
    required ReviewLog log,
    required ItemState state,
  }) async {
    await _gate;
    await _inner.recordReview(log: log, state: state);
  }

  @override
  Future<int> countNewItemsFirstShown({
    required DateTime from,
    required DateTime to,
  }) => _inner.countNewItemsFirstShown(from: from, to: to);

  @override
  Future<Map<String, ItemContent>> contentFor(Set<String> itemIds) =>
      _inner.contentFor(itemIds);

  @override
  Future<List<ItemState>> dueStates({
    required DateTime now,
    Set<String>? deckIds,
  }) => _inner.dueStates(now: now, deckIds: deckIds);

  @override
  Future<Map<String, DateTime>> lastShownAt(Set<String> itemIds) =>
      _inner.lastShownAt(itemIds);

  @override
  Future<List<LocalItem>> newItems({
    Set<String>? deckIds,
    required int limit,
  }) => _inner.newItems(deckIds: deckIds, limit: limit);

  @override
  Future<DateTime?> nextDue({required DateTime after, Set<String>? deckIds}) =>
      _inner.nextDue(after: after, deckIds: deckIds);
}
