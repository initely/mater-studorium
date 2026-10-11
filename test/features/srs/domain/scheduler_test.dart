import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/scheduler.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

import '../../../helpers/deck_fixtures.dart';

final t0 = DateTime.utc(2026, 10, 11, 12);
const scheduler = Scheduler();

ItemState fresh([DateTime? now]) =>
    Scheduler.initialState(itemId: 'i', deckId: 'd', now: now ?? t0);

/// Прогоняет оценки, отвечая ровно в момент `due` предыдущего шага.
List<ItemState> runOnTime(List<Rating> ratings, {Scheduler s = scheduler}) {
  var state = fresh();
  var now = t0;
  final out = <ItemState>[];
  for (final r in ratings) {
    state = s.review(state, r, now);
    out.add(state);
    now = state.due;
  }
  return out;
}

ItemState reviewState({double stability = 20, double difficulty = 5}) =>
    fresh().copyWith(
      state: SrsState.review,
      stability: stability,
      difficulty: difficulty,
      reps: 5,
      lapses: 1,
      lastReview: t0.subtract(const Duration(days: 20)),
      due: t0,
      scheduledDays: 20,
    );

void expectInvariants(ItemState before, ItemState after, DateTime at) {
  expect(after.stability, greaterThan(0));
  expect(after.stability.isFinite, isTrue);
  expect(after.difficulty, inInclusiveRange(1, 10));
  expect(after.due.isUtc, isTrue);
  expect(after.due.isAfter(at), isTrue, reason: 'due > now');
  expect(after.lastReview, at.toUtc());
  expect(after.updatedAt, at.toUtc());
  expect(after.reps, before.reps + 1);
  expect(after.lapses, inInclusiveRange(before.lapses, before.lapses + 1));
  expect(after.state, isNot(SrsState.newCard));
  expect(after.elapsedDays, greaterThanOrEqualTo(0));
  if (after.state == SrsState.review) {
    expect(after.scheduledDays, inInclusiveRange(1, 36500));
  } else {
    expect(after.scheduledDays, 0);
  }
}

void main() {
  group('совпадение с эталоном py-fsrs 6.3.2', () {
    final golden = readJsonFile('test/fixtures/srs/py_fsrs_6_3_2.json');
    final scenarios = golden['scenarios'] as Map<String, dynamic>;

    test('сценарии есть', () => expect(scenarios.length, greaterThan(5)));

    for (final MapEntry(key: name, value: raw) in scenarios.entries) {
      test(name, () {
        final scenario = raw as Map<String, dynamic>;
        final s = Scheduler(
          maximumIntervalDays: scenario['maxInterval'] as int,
        );
        var state = fresh();
        var i = 0;
        for (final step
            in (scenario['steps'] as List<dynamic>)
                .cast<Map<String, dynamic>>()) {
          final at = DateTime.parse(step['at'] as String);
          state = s.review(state, Rating.fromCode(step['rating'] as int), at);
          final where = '$name, шаг $i';
          expect(state.state.name, step['state'], reason: where);
          expect(
            state.stability,
            closeTo(step['s'] as num, 1e-9),
            reason: where,
          );
          expect(
            state.difficulty,
            closeTo(step['d'] as num, 1e-9),
            reason: where,
          );
          expect(
            state.due,
            DateTime.parse(step['due'] as String),
            reason: where,
          );
          i++;
        }
      });
    }
  });

  group('AC7.1', () {
    final starts = <String, ItemState>{
      'новое': fresh(),
      'learning': scheduler.review(fresh(), Rating.again, t0),
      'review': reviewState(),
      'relearning': scheduler.review(reviewState(), Rating.again, t0),
    };
    for (final MapEntry(key: name, value: start) in starts.entries) {
      test('$name: due после Again раньше, чем после Good', () {
        final at = start.due.add(const Duration(hours: 1));
        final again = scheduler.review(start, Rating.again, at);
        final good = scheduler.review(start, Rating.good, at);
        expect(again.due.isBefore(good.due), isTrue);
      });
    }

    test('детерминированность: одинаковый вход — одинаковое состояние', () {
      for (final start in starts.values) {
        for (final r in Rating.values) {
          final at = start.due.add(const Duration(days: 2));
          expect(
            scheduler.review(start, r, at),
            scheduler.review(start, r, at),
          );
        }
      }
      expect(
        runOnTime([for (var i = 0; i < 5; i++) ...Rating.values]),
        runOnTime([for (var i = 0; i < 5; i++) ...Rating.values]),
      );
    });
  });

  group('новое знание', () {
    test('initialState: state=newCard, due=now в UTC', () {
      final local = DateTime(2026, 10, 11, 15);
      final s = fresh(local);
      expect(s.state, SrsState.newCard);
      expect(s.due, local.toUtc());
      expect(s.due.isUtc, isTrue);
      expect(s.updatedAt.isUtc, isTrue);
      expect([s.reps, s.lapses, s.elapsedDays, s.scheduledDays], [0, 0, 0, 0]);
      expect(s.lastReview, isNull);
    });

    test('первая оценка: шаги и начальная стабильность FSRS-6', () {
      ItemState first(Rating r) => scheduler.review(fresh(), r, t0);

      final again = first(Rating.again);
      expect(again.state, SrsState.learning);
      expect(again.due, t0.add(const Duration(minutes: 10)));
      expect(again.stability, kFsrs6DefaultParameters[0]);

      final hard = first(Rating.hard);
      expect(hard.state, SrsState.learning);
      expect(hard.due, t0.add(const Duration(minutes: 15)));

      final good = first(Rating.good);
      expect(good.state, SrsState.review);
      expect(good.due, t0.add(const Duration(days: 2)));
      expect(good.scheduledDays, 2);

      final easy = first(Rating.easy);
      expect(easy.state, SrsState.review);
      expect(easy.due, t0.add(const Duration(days: 8)));

      for (final r in Rating.values) {
        final s = first(r);
        expect(s.reps, 1);
        expect(s.lapses, 0, reason: 'lapse бывает только из review');
        expect(s.elapsedDays, 0);
        expect(s.lastReview, t0);
      }
      // Чем лучше оценка, тем ниже сложность.
      final d = [for (final r in Rating.values) first(r).difficulty];
      final descending = [...d]..sort((a, b) => b.compareTo(a));
      expect(d, orderedEquals(descending));
      expect(d.toSet().length, 4);
    });

    test('сохраняет поля, которые планировщик не трогает', () {
      final s = scheduler.review(
        fresh().copyWith(lastQuestionId: 'i.q2'),
        Rating.good,
        t0,
      );
      expect(s.itemId, 'i');
      expect(s.deckId, 'd');
      expect(s.lastQuestionId, 'i.q2');
    });
  });

  group('learning и relearning', () {
    test('Again и Hard оставляют в том же состоянии, Good выпускает', () {
      final learning = scheduler.review(fresh(), Rating.again, t0);
      final relearning = scheduler.review(reviewState(), Rating.again, t0);
      for (final start in [learning, relearning]) {
        final at = start.due;
        expect(scheduler.review(start, Rating.again, at).state, start.state);
        expect(scheduler.review(start, Rating.hard, at).state, start.state);
        expect(
          scheduler.review(start, Rating.again, at).due,
          at.add(Scheduler.shortStep),
        );
        expect(scheduler.review(start, Rating.good, at).state, SrsState.review);
        expect(scheduler.review(start, Rating.easy, at).state, SrsState.review);
        expect(
          scheduler.review(start, Rating.again, at).lapses,
          start.lapses,
          reason: 'Again в learning/relearning — не новый lapse',
        );
      }
    });
  });

  group('динамика интервалов', () {
    test('серия Good: интервалы растут (монотонно)', () {
      final states = runOnTime(List.filled(10, Rating.good));
      final days = [for (final s in states) s.scheduledDays];
      for (var i = 1; i < days.length; i++) {
        expect(days[i], greaterThan(days[i - 1]), reason: '$days');
      }
      expect(days.first, 2);
      expect(days.last, greaterThan(365));
    });

    test('Easy > Good > Hard по интервалу в review', () {
      final start = reviewState();
      int days(Rating r) => scheduler.review(start, r, t0).scheduledDays;
      expect(days(Rating.easy), greaterThan(days(Rating.good)));
      expect(days(Rating.good), greaterThan(days(Rating.hard)));
    });

    test('сброс при Again: relearning, 10 минут, lapse, S падает', () {
      final before = reviewState(stability: 60);
      final lapsed = scheduler.review(before, Rating.again, t0);
      expect(lapsed.state, SrsState.relearning);
      expect(lapsed.due, t0.add(const Duration(minutes: 10)));
      expect(lapsed.scheduledDays, 0);
      expect(lapsed.lapses, before.lapses + 1);
      expect(lapsed.stability, lessThan(before.stability / 2));
      expect(lapsed.difficulty, greaterThan(before.difficulty));

      final back = scheduler.review(lapsed, Rating.good, lapsed.due);
      expect(back.state, SrsState.review);
      expect(back.scheduledDays, inInclusiveRange(1, 59));
    });

    test('опоздание с ответом даёт больший рост S, чем ответ вовремя', () {
      final start = reviewState();
      final onTime = scheduler.review(start, Rating.good, t0);
      final late = scheduler.review(
        start,
        Rating.good,
        t0.add(const Duration(days: 30)),
      );
      expect(late.stability, greaterThan(onTime.stability));
      expect(late.elapsedDays, 50);
    });
  });

  group('границы', () {
    test('интервал не больше maximumIntervalDays', () {
      const capped = Scheduler(maximumIntervalDays: 30);
      final states = runOnTime(List.filled(8, Rating.easy), s: capped);
      expect(states.last.scheduledDays, 30);
      expect(states.every((s) => s.scheduledDays <= 30), isTrue);
    });

    test('в review интервал не меньше суток', () {
      final s = scheduler.review(
        reviewState(stability: 0.01, difficulty: 10),
        Rating.hard,
        t0,
      );
      expect(s.state, SrsState.review);
      expect(s.scheduledDays, 1);
    });

    test('now в локальной зоне: due и lastReview в UTC, тот же момент', () {
      final local = DateTime(2026, 10, 11, 15, 30);
      final s = scheduler.review(reviewState(), Rating.good, local);
      expect(s.due.isUtc, isTrue);
      expect(s.lastReview!.isUtc, isTrue);
      expect(s.lastReview, local.toUtc());
      expect(s, scheduler.review(reviewState(), Rating.good, local.toUtc()));
    });

    test('ответ в тот же день: краткосрочная стабильность, elapsed=0', () {
      final start = reviewState().copyWith(
        lastReview: t0.subtract(const Duration(hours: 3)),
      );
      final s = scheduler.review(start, Rating.good, t0);
      expect(s.elapsedDays, 0);
      expect(s.stability, greaterThanOrEqualTo(start.stability));
    });

    test('часы ушли назад (now < lastReview): без падения', () {
      final start = reviewState().copyWith(
        lastReview: t0.add(const Duration(days: 2)),
      );
      for (final r in Rating.values) {
        final s = scheduler.review(start, r, t0);
        expectInvariants(start, s, t0);
        expect(s.elapsedDays, 0);
      }
    });

    test('испорченное состояние (S=0, D=0) не даёт NaN', () {
      final broken = reviewState(stability: 0, difficulty: 0);
      for (final r in Rating.values) {
        expectInvariants(broken, scheduler.review(broken, r, t0), t0);
      }
    });
  });

  test('инварианты на случайных траекториях (S>0, D∈[1,10], due>now)', () {
    final rnd = math.Random(20261011);
    for (var run = 0; run < 300; run++) {
      var state = fresh();
      var now = t0;
      for (var step = 0; step < 25; step++) {
        final before = state;
        final r = Rating.values[rnd.nextInt(4)];
        state = scheduler.review(state, r, now);
        expectInvariants(before, state, now);
        // Следующий ответ: от «сразу» до +60 дней после due.
        final span = state.due.difference(now).inSeconds;
        now = now.add(Duration(seconds: 1 + rnd.nextInt(span + 60 * 86400)));
      }
    }
  });
}
