import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/domain/item_content.dart';
import 'package:mater_studorium/features/session/domain/local_day.dart';
import 'package:mater_studorium/features/session/domain/session_queue.dart';
import 'package:mater_studorium/features/session/domain/session_queue_builder.dart';
import 'package:mater_studorium/features/session/domain/session_settings.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/scheduler.dart';

import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/time_zones.dart';

Duration h(int hours) => Duration(hours: hours);

SessionQueueBuilder builderFor(
  FakeSessionRepository repo, {
  int seed = 1,
  UtcOffsetAt? zone,
}) => SessionQueueBuilder(
  repository: repo,
  random: math.Random(seed),
  utcOffsetAt: zone ?? fixedOffset(Duration.zero),
);

List<String> ids(SessionQueue queue) => [
  for (final i in queue.items) i.item.id,
];

/// Знания `prefix1..prefixN`.
List<ItemContent> items(String prefix, int n, {String deckId = 'd1'}) => [
  for (var i = 1; i <= n; i++) fakeContent('$prefix$i', deckId: deckId),
];

void main() {
  final now = fakeNow;

  group('порядок и состав (AC3.1)', () {
    test(
      'сначала due по возрастанию due, затем новые в порядке колоды',
      () async {
        final repo = FakeSessionRepository(
          contents: [...items('n', 3), ...items('r', 3)],
          states: {
            'r1': fakeState('r1', now.subtract(h(1))),
            'r2': fakeState('r2', now.subtract(const Duration(days: 3))),
            'r3': fakeState('r3', now.subtract(h(30))),
          },
        );

        final queue = await builderFor(repo).build(now: now);

        expect(ids(queue), ['r2', 'r3', 'r1', 'n1', 'n2', 'n3']);
        expect(queue.dueCount, 3);
        expect(queue.newCount, 3);
        expect(queue.items.map((i) => i.isNew), [
          false,
          false,
          false,
          true,
          true,
          true,
        ]);
        expect(queue.isEmpty, isFalse);
        expect(queue.emptyReason, isNull);
      },
    );

    test('due == now входит, будущие не входят', () async {
      final repo = FakeSessionRepository(
        contents: items('r', 3),
        states: {
          'r1': fakeState('r1', now),
          'r2': fakeState('r2', now.add(const Duration(seconds: 1))),
          'r3': fakeState('r3', now.add(const Duration(days: 2))),
        },
      );

      final queue = await builderFor(repo).build(now: now);

      expect(ids(queue), ['r1']);
      // Ближайшее будущее повторение видно для «следующее — через …».
      expect(queue.nextDue, now.add(const Duration(seconds: 1)));
    });

    test(
      'новое знание в очереди: состояние newCard, колода и версия',
      () async {
        final repo = FakeSessionRepository(
          contents: [fakeContent('n1', deckId: 'dk', deckVersion: 7)],
        );

        final item = (await builderFor(repo).build(now: now)).items.single;

        expect(
          item.state,
          Scheduler.initialState(itemId: 'n1', deckId: 'dk', now: now),
        );
        expect(item.deckVersion, 7);
        expect(item.item.deckId, 'dk');
      },
    );

    test(
      'каждое знание не больше одного раза, у каждого один вопрос',
      () async {
        final repo = FakeSessionRepository(
          contents: [...items('n', 4), ...items('r', 4)],
          states: {
            for (var i = 1; i <= 4; i++)
              'r$i': fakeState('r$i', now.subtract(h(i))),
          },
        );

        final queue = await builderFor(repo).build(now: now);

        expect(ids(queue).toSet(), hasLength(queue.items.length));
        expect(queue.items, hasLength(8));
        for (final i in queue.items) {
          expect(i.question.id, startsWith(i.item.id));
        }
      },
    );

    test('now не в UTC приводится к UTC', () async {
      final repo = FakeSessionRepository(
        contents: items('r', 1),
        states: {'r1': fakeState('r1', now)},
      );
      final local = DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch,
      );

      expect(ids(await builderFor(repo).build(now: local)), ['r1']);
    });
  });

  group('лимит новых', () {
    test('не больше newPerDay; остальные ждут', () async {
      final repo = FakeSessionRepository(contents: items('n', 15));

      final queue = await builderFor(repo)
          .build(now: now, settings: const SessionSettings(sessionSize: 50));

      expect(ids(queue), [for (var i = 1; i <= 10; i++) 'n$i']);
      expect(queue.moreNewAvailable, isTrue);
    });

    test('ровно столько новых, сколько осталось, больше нет', () async {
      final repo = FakeSessionRepository(contents: items('n', 10));

      final queue = await builderFor(repo)
          .build(now: now, settings: const SessionSettings(sessionSize: 50));

      expect(queue.newCount, 10);
      expect(queue.moreNewAvailable, isFalse);
    });

    test('newPerDay = 0: только повторения', () async {
      final repo = FakeSessionRepository(
        contents: [...items('n', 3), ...items('r', 1)],
        states: {'r1': fakeState('r1', now)},
      );

      final queue = await builderFor(repo)
          .build(now: now, settings: const SessionSettings(newPerDay: 0));

      expect(ids(queue), ['r1']);
      expect(queue.moreNewAvailable, isTrue);
    });

    test('уже показанные сегодня новые уменьшают остаток', () async {
      // n1..n4 впервые показаны сегодня (UTC); n5..n9 новые.
      final repo = FakeSessionRepository(
        contents: items('n', 9),
        states: {
          for (var i = 1; i <= 4; i++)
            'n$i': fakeState('n$i', now.add(const Duration(days: 1))),
        },
        logs: [
          for (var i = 1; i <= 4; i++)
            fakeLog('n$i', DateTime.utc(2026, 10, 11, i)),
        ],
      );

      final queue = await builderFor(repo).build(
        now: now,
        settings: const SessionSettings(newPerDay: 6, sessionSize: 50),
      );

      expect(ids(queue), ['n5', 'n6']);
      expect(repo.countFrom, DateTime.utc(2026, 10, 11));
      expect(repo.countTo, DateTime.utc(2026, 10, 12));
    });

    test('показанные вчера и повторы сегодня новыми не считаются', () async {
      final repo = FakeSessionRepository(
        contents: items('n', 12),
        states: {
          for (var i = 1; i <= 2; i++)
            'n$i': fakeState('n$i', now.add(const Duration(days: 1))),
        },
        logs: [
          // n1: впервые вчера, сегодня повторили.
          fakeLog('n1', DateTime.utc(2026, 10, 10, 23, 59, 59)),
          fakeLog('n1', DateTime.utc(2026, 10, 11, 8)),
          // n2: впервые вчера, повторов сегодня нет.
          fakeLog('n2', DateTime.utc(2026, 10, 10, 9)),
        ],
      );

      final queue = await builderFor(repo).build(now: now);

      // Лимит 10 целиком доступен: n3..n12.
      expect(queue.newCount, 10);
      expect(ids(queue).first, 'n3');
    });

    test('лимит исчерпан: очередь пуста, причина — newLimitReached', () async {
      final repo = FakeSessionRepository(
        contents: items('n', 5),
        states: {
          for (var i = 1; i <= 3; i++)
            'n$i': fakeState('n$i', now.add(const Duration(days: 1))),
        },
        logs: [for (var i = 1; i <= 3; i++) fakeLog('n$i', now)],
      );

      final queue = await builderFor(repo)
          .build(now: now, settings: const SessionSettings(newPerDay: 3));

      expect(queue.isEmpty, isTrue);
      expect(queue.emptyReason, EmptyQueueReason.newLimitReached);
      expect(queue.moreNewAvailable, isTrue);
      expect(queue.nextDue, now.add(const Duration(days: 1)));
    });

    test(
      'лимит уже превышен («Взять новые» раньше): остаток 0, не минус',
      () async {
        final repo = FakeSessionRepository(
          contents: items('n', 8),
          states: {
            for (var i = 1; i <= 5; i++)
              'n$i': fakeState('n$i', now.add(const Duration(days: 1))),
          },
          logs: [for (var i = 1; i <= 5; i++) fakeLog('n$i', now)],
        );

        final queue = await builderFor(repo)
            .build(now: now, settings: const SessionSettings(newPerDay: 3));

        expect(queue.isEmpty, isTrue);
      },
    );

    test('повторный запуск в тот же день: лимит общий на сутки', () async {
      final repo = FakeSessionRepository(contents: items('n', 30));
      final builder = builderFor(repo);
      const settings = SessionSettings(newPerDay: 10, sessionSize: 50);

      // Первая сессия: показали и ответили на 6 из 10 новых.
      final first = await builder.build(now: now, settings: settings);
      expect(first.newCount, 10);
      for (final item in first.items.take(6)) {
        final at = now.add(const Duration(minutes: 1));
        await repo.recordReview(
          log: fakeLog(item.item.id, at),
          state: const Scheduler().review(item.state, Rating.good, at),
        );
      }

      // Вторая, через час: ответившие 6 уже не новые, и их 6 из 10 сегодня.
      final second = await builder.build(
        now: now.add(const Duration(hours: 1)),
        settings: settings,
      );
      expect(second.newCount, 4, reason: '10 в день минус 6 уже взятых');
      expect(ids(second), ['n7', 'n8', 'n9', 'n10']);

      // Ответили на все 10: до завтра новых нет.
      for (final item in second.items) {
        final at = now.add(const Duration(hours: 1, minutes: 1));
        await repo.recordReview(
          log: fakeLog(item.item.id, at),
          state: const Scheduler().review(item.state, Rating.good, at),
        );
      }
      final third = await builder.build(
        now: now.add(const Duration(hours: 2)),
        settings: settings,
      );
      expect(third.newCount, 0);
      expect(third.emptyReason, EmptyQueueReason.newLimitReached);

      // Следующие сутки: лимит обнулился.
      final tomorrow = await builder.build(
        now: now.add(const Duration(days: 1)),
        settings: settings,
      );
      expect(tomorrow.newCount, 10);
      expect(ids(tomorrow).first, 'n11');
    });

    test('«Взять новые» (extraNew) поверх исчерпанного лимита', () async {
      final repo = FakeSessionRepository(
        contents: items('n', 20),
        states: {
          for (var i = 1; i <= 3; i++)
            'n$i': fakeState('n$i', now.add(const Duration(days: 1))),
        },
        logs: [for (var i = 1; i <= 3; i++) fakeLog('n$i', now)],
      );
      const settings = SessionSettings(newPerDay: 3);

      final queue = await builderFor(repo)
          .build(now: now, settings: settings, extraNew: 5);

      expect(ids(queue), ['n4', 'n5', 'n6', 'n7', 'n8']);
      expect(queue.moreNewAvailable, isTrue);
    });

    test(
      'extraNew прибавляется к остатку и ограничен размером сессии',
      () async {
        final repo = FakeSessionRepository(contents: items('n', 20));

        final queue = await builderFor(repo).build(
          now: now,
          settings: const SessionSettings(newPerDay: 4, sessionSize: 6),
          extraNew: 5,
        );

        expect(queue.newCount, 6, reason: 'min(4 + 5, размер сессии 6)');
      },
    );
  });

  group('размер сессии', () {
    test('повторения занимают места первыми, новые добирают остаток', () async {
      final repo = FakeSessionRepository(
        contents: [...items('n', 10), ...items('r', 3)],
        states: {
          for (var i = 1; i <= 3; i++)
            'r$i': fakeState('r$i', now.subtract(h(i))),
        },
      );

      final queue = await builderFor(repo)
          .build(now: now, settings: const SessionSettings(sessionSize: 5));

      expect(ids(queue), ['r3', 'r2', 'r1', 'n1', 'n2']);
    });

    test(
      'повторений больше размера: берутся самые просроченные, новых нет',
      () async {
        final repo = FakeSessionRepository(
          contents: [...items('n', 3), ...items('r', 6)],
          states: {
            for (var i = 1; i <= 6; i++)
              'r$i': fakeState('r$i', now.subtract(h(i))),
          },
        );

        final queue = await builderFor(repo)
            .build(now: now, settings: const SessionSettings(sessionSize: 4));

        expect(ids(queue), ['r6', 'r5', 'r4', 'r3']);
        expect(queue.newCount, 0);
        expect(queue.moreNewAvailable, isTrue);
      },
    );
  });

  group('пустая очередь (AC3.1, AC3.3)', () {
    test('колоды не скачаны: noContent, без исключения', () async {
      final queue = await builderFor(FakeSessionRepository()).build(now: now);

      expect(queue.items, isEmpty);
      expect(queue.isEmpty, isTrue);
      expect(queue.emptyReason, EmptyQueueReason.noContent);
      expect(queue.nextDue, isNull);
      expect(queue.moreNewAvailable, isFalse);
      expect(queue.dueCount, 0);
      expect(queue.newCount, 0);
    });

    test('всё повторено, новых нет: allDone и время следующего', () async {
      final repo = FakeSessionRepository(
        contents: items('r', 2),
        states: {
          'r1': fakeState('r1', now.add(h(3))),
          'r2': fakeState('r2', now.add(h(1))),
        },
      );

      final queue = await builderFor(repo).build(now: now);

      expect(queue.emptyReason, EmptyQueueReason.allDone);
      expect(queue.nextDue, now.add(h(1)));
    });
  });

  group('колоды', () {
    test('deckIds передаются в хранилище и ограничивают очередь', () async {
      final repo = FakeSessionRepository(
        contents: [
          ...items('a', 2, deckId: 'A'),
          ...items('b', 2, deckId: 'B'),
        ],
      );

      final queue = await builderFor(repo).build(
        now: now,
        settings: const SessionSettings(deckIds: {'B'}),
      );

      expect(ids(queue), ['b1', 'b2']);
      expect(repo.lastDeckIds, {'B'});
    });
  });

  group('выбор варианта (VariantPicker)', () {
    test(
      'новое знание: без open, первый показ — mcq; flip приоритетнее',
      () async {
        final repo = FakeSessionRepository(
          contents: [
            fakeContent('n1'),
            fakeContent(
              'n2',
              questions: [
                fakeQuestion('n2.mcq', QuestionType.mcq),
                fakeQuestion('n2.flip', QuestionType.flip),
              ],
            ),
          ],
        );

        final queue = await builderFor(repo).build(now: now);

        expect(queue.items.map((i) => i.question.id), ['n1.mcq', 'n2.flip']);
      },
    );

    test(
      'повторение: тип отличается от прошлого, open — когда S >= 3',
      () async {
        final repo = FakeSessionRepository(
          contents: [fakeContent('r1'), fakeContent('r2')],
          states: {
            'r1': fakeState(
              'r1',
              now.subtract(h(2)),
              stability: 10,
              lastQuestionId: 'r1.mcq',
            ),
            // S < 3: open не показываем, даже раз прошлый был mcq.
            'r2': fakeState(
              'r2',
              now.subtract(h(1)),
              stability: 1,
              lastQuestionId: 'r2.mcq',
            ),
          },
        );

        final queue = await builderFor(repo).build(now: now);

        expect(queue.items.map((i) => i.question.id), ['r1.open', 'r2.mcq']);
      },
    );

    test('давность показа берётся из логов', () async {
      final repo = FakeSessionRepository(
        contents: [
          fakeContent(
            'r1',
            questions: [
              fakeQuestion('r1.a', QuestionType.mcq),
              fakeQuestion('r1.b', QuestionType.mcq),
              fakeQuestion('r1.c', QuestionType.flip),
            ],
          ),
        ],
        states: {
          'r1': fakeState('r1', now, stability: 10, lastQuestionId: 'r1.c'),
        },
        logs: [
          fakeLog('r1', DateTime.utc(2026, 10, 1), questionId: 'r1.a'),
          fakeLog('r1', DateTime.utc(2026, 10, 5), questionId: 'r1.b'),
          fakeLog('r1', DateTime.utc(2026, 10, 9), questionId: 'r1.c'),
        ],
      );

      final queue = await builderFor(repo).build(now: now);

      expect(queue.items.single.question.id, 'r1.a');
    });

    test('знание без содержимого пропускается, остальные на местах', () async {
      final repo = FakeSessionRepository(
        contents: [
          fakeContent('r1'),
          fakeContent('r2'),
          fakeContent('n1'),
          fakeContent('n2'),
        ],
        states: {
          'r1': fakeState('r1', now.subtract(h(3))),
          'r2': fakeState('r2', now.subtract(h(2))),
        },
      )..missingContent.addAll({'r2', 'n1'});

      final queue = await builderFor(repo).build(now: now);

      expect(ids(queue), ['r1', 'n2']);
      expect(queue.dueCount, 1);
      expect(queue.newCount, 1);
    });

    test('вопросы, которых picker не нашёл, не ломают очередь', () async {
      final repo = _NoVisibleQuestions(
        contents: [fakeContent('r1'), fakeContent('n1')],
        states: {'r1': fakeState('r1', now)},
      );

      final queue = await builderFor(repo).build(now: now);

      expect(queue.items, isEmpty);
    });
  });

  group('случайность', () {
    // 6 знаний с одинаковым due и 6 с разными.
    FakeSessionRepository tiedRepo() {
      final tied = now.subtract(h(5));
      return FakeSessionRepository(
        contents: [...items('t', 6), ...items('r', 6)],
        states: {
          for (var i = 1; i <= 6; i++) 't$i': fakeState('t$i', tied),
          for (var i = 1; i <= 6; i++)
            'r$i': fakeState('r$i', now.subtract(h(i + 10))),
        },
      );
    }

    test('одинаковый seed — одинаковая очередь, вопросы тоже', () async {
      for (final seed in [0, 1, 42]) {
        final a = await builderFor(tiedRepo(), seed: seed).build(now: now);
        final b = await builderFor(tiedRepo(), seed: seed).build(now: now);
        expect(ids(a), ids(b));
        expect(
          a.items.map((i) => i.question.id),
          b.items.map((i) => i.question.id),
        );
      }
    });

    test(
      'перемешивание только среди равных due, приоритет не нарушается',
      () async {
        final orders = <String>{};
        for (var seed = 0; seed < 30; seed++) {
          final queue = await builderFor(
            tiedRepo(),
            seed: seed,
          ).build(now: now, settings: const SessionSettings(sessionSize: 50));
          final due = [for (final i in queue.items) i.state.due];
          // due не убывает: просроченные раньше всегда впереди.
          expect(
            [...due]..sort(),
            due,
            reason: 'seed $seed: порядок по due нарушен',
          );
          // Сначала шесть самых давних (r6..r1 по убыванию просрочки), затем
          // равные t* в любом порядке.
          expect(ids(queue).take(6), ['r6', 'r5', 'r4', 'r3', 'r2', 'r1']);
          expect(ids(queue).skip(6).toSet(), {
            for (var i = 1; i <= 6; i++) 't$i',
          });
          orders.add(ids(queue).skip(6).join(','));
        }
        expect(
          orders.length,
          greaterThan(1),
          reason: 'равные due перемешиваются',
        );
      },
    );

    test('без равных due случайность порядок не меняет', () async {
      final repo = FakeSessionRepository(
        contents: items('r', 4),
        states: {
          for (var i = 1; i <= 4; i++)
            'r$i': fakeState('r$i', now.subtract(h(i))),
        },
      );
      for (var seed = 0; seed < 5; seed++) {
        final queue = await builderFor(repo, seed: seed).build(now: now);
        expect(ids(queue), ['r4', 'r3', 'r2', 'r1']);
      }
    });
  });

  group('граница суток (часовой пояс пользователя)', () {
    // Одно новое знание n1 впервые показано в [logAt]; считается ли оно
    // «сегодняшним» для пользователя в поясе [zone] в момент [at].
    Future<int> newLeft(
      DateTime logAt,
      DateTime at,
      UtcOffsetAt zone, {
      FakeSessionRepository? repo,
    }) async {
      final r =
          repo ??
          FakeSessionRepository(
            contents: items('n', 20),
            states: {'n1': fakeState('n1', at.add(const Duration(days: 1)))},
            logs: [fakeLog('n1', logAt)],
          );
      final queue = await builderFor(r, zone: zone).build(
        now: at,
        settings: const SessionSettings(newPerDay: 5, sessionSize: 50),
      );
      return queue.newCount;
    }

    test(
      'Москва UTC+3: 00:30 по Москве — уже сегодня, по UTC — вчера',
      () async {
        final logAt = DateTime.utc(2026, 10, 10, 21, 30); // 00:30 MSK, 11.10
        final at = DateTime.utc(2026, 10, 11, 5); // 08:00 MSK, 11.10

        expect(await newLeft(logAt, at, fixedOffset(h(3))), 4);
        expect(await newLeft(logAt, at, fixedOffset(Duration.zero)), 5);
      },
    );

    test('Москва: 23:30 по Москве вчера не считается сегодня', () async {
      final logAt = DateTime.utc(2026, 10, 10, 20, 30); // 23:30 MSK, 10.10
      final at = DateTime.utc(2026, 10, 11, 5); // 08:00 MSK, 11.10

      expect(await newLeft(logAt, at, fixedOffset(h(3))), 5);
      // По UTC лог тоже вчерашний (20:30Z 10.10).
      expect(await newLeft(logAt, at, fixedOffset(Duration.zero)), 5);
    });

    test('UTC-8: вечер по UTC — ещё то же локальное «сегодня»', () async {
      final logAt = DateTime.utc(2026, 10, 11, 9); // 01:00 PDT-ish, 11.10
      final at = DateTime.utc(2026, 10, 12, 6); // 22:00, 11.10 (UTC-8)

      expect(await newLeft(logAt, at, fixedOffset(h(-8))), 4);
      // По UTC log был «вчера» относительно 12.10.
      expect(await newLeft(logAt, at, fixedOffset(Duration.zero)), 5);
    });

    test('точная граница: лог ровно в начале суток — сегодня, на микросекунду раньше — вчера', () async {
      final start = DateTime.utc(2026, 10, 10, 21); // 00:00 MSK, 11.10
      final at = DateTime.utc(2026, 10, 11, 5);

      expect(await newLeft(start, at, fixedOffset(h(3))), 4);
      expect(
        await newLeft(
          start.subtract(const Duration(microseconds: 1)),
          at,
          fixedOffset(h(3)),
        ),
        5,
      );
    });

    test(
      'Нью-Йорк, 1 ноября (сутки 25 часов): лимит один на все 25 часов',
      () async {
        // День 1.11 по Нью-Йорку: 04:00Z .. 05:00Z 2.11.
        final first = DateTime.utc(2026, 11, 1, 4, 30); // 00:30 EDT
        final at = DateTime.utc(2026, 11, 2, 4, 30); // 23:30 EST, 1.11
        expect(await newLeft(first, at, newYork), 4);
        // Фиксированное летнее смещение -4 «закончило» бы сутки на час раньше.
        expect(await newLeft(first, at, fixedOffset(h(-4))), 5);
      },
    );

    test(
      'Нью-Йорк, 8 марта (сутки 23 часа): 23:30 EST 7 марта — вчера',
      () async {
        final late = DateTime.utc(2026, 3, 8, 4, 30); // 23:30 EST, 7.03
        final at = DateTime.utc(2026, 3, 8, 15); // 11:00 EDT, 8.03
        expect(await newLeft(late, at, newYork), 5);
        // Фиксированное -4 приняло бы этот лог за сегодняшний.
        expect(await newLeft(late, at, fixedOffset(h(-4))), 4);

        final early = DateTime.utc(2026, 3, 8, 5, 30); // 00:30 EST, 8.03
        expect(await newLeft(early, at, newYork), 4);
      },
    );

    test('Нью-Йорк: границы суток в запросе к хранилищу', () async {
      final repo = FakeSessionRepository(contents: items('n', 1));
      await builderFor(
        repo,
        zone: newYork,
      ).build(now: DateTime.utc(2026, 11, 1, 12));

      expect(repo.countFrom, DateTime.utc(2026, 11, 1, 4));
      expect(repo.countTo, DateTime.utc(2026, 11, 2, 5));
    });

    test('сутки с пропущенной полуночью (Сан-Паулу, 2018)', () async {
      final repo = FakeSessionRepository(contents: items('n', 1));
      await builderFor(
        repo,
        zone: saoPauloSkippedMidnight,
      ).build(now: DateTime.utc(2018, 11, 4, 12));

      expect(repo.countFrom, DateTime.utc(2018, 11, 4, 3));
      expect(repo.countTo, DateTime.utc(2018, 11, 5, 2));
    });
  });

  group('поддерживаемые форматы (реестр, T13)', () {
    // У знаний по умолчанию варианты mcq и open.
    SessionQueueBuilder withTypes(
      FakeSessionRepository repo,
      Set<QuestionType>? types,
    ) => SessionQueueBuilder(
      repository: repo,
      random: math.Random(1),
      utcOffsetAt: fixedOffset(Duration.zero),
      supportedTypes: types,
    );

    test('вариант неподдерживаемого типа не выбирается', () async {
      // Состояние review со стабильностью 5 дней: open разрешён по §4.1,
      // но реестр его не знает — остаётся mcq.
      final repo = FakeSessionRepository(
        contents: items('r', 5),
        states: {
          for (var i = 1; i <= 5; i++)
            'r$i': fakeState('r$i', now.subtract(h(i))),
        },
      );
      final queue = await withTypes(repo, {QuestionType.mcq}).build(now: now);

      expect(queue.items, hasLength(5));
      expect(queue.items.map((i) => i.question.type).toSet(), {
        QuestionType.mcq,
      });
    });

    test('знание без поддерживаемого варианта пропускается', () async {
      final repo = FakeSessionRepository(
        contents: [
          fakeContent(
            'only-open',
            questions: [fakeQuestion('only-open.open', QuestionType.open)],
          ),
          fakeContent('n1'),
        ],
      );
      final queue = await withTypes(repo, {QuestionType.mcq}).build(now: now);

      expect(ids(queue), ['n1']);
      expect(queue.newCount, 1);
    });

    test('null — поддерживаются все типы', () async {
      final repo = FakeSessionRepository(
        contents: [
          fakeContent(
            'only-open',
            questions: [fakeQuestion('only-open.open', QuestionType.open)],
          ),
        ],
      );
      final queue = await withTypes(repo, null).build(now: now);
      expect(ids(queue), ['only-open']);
    });
  });
}

/// Репозиторий, который отдаёт знания с вопросами, но picker не находит
/// видимых (страховка от гонки).
class _NoVisibleQuestions extends FakeSessionRepository {
  _NoVisibleQuestions({super.contents, super.states});

  @override
  Future<Map<String, ItemContent>> contentFor(Set<String> itemIds) async => {
    for (final c in contents)
      if (itemIds.contains(c.item.id))
        c.item.id: ItemContent(
          item: c.item,
          deckVersion: c.deckVersion,
          questions: const [],
        ),
  };
}
