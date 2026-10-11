import 'dart:math' as math;

import 'item_state.dart';
import 'rating.dart';
import 'srs_state.dart';

/// Желаемая удерживаемость (ТЗ §4.1): планируем повторение на момент, когда
/// вероятность вспомнить падает до 90%. Единственное место, где задаётся.
const double kDesiredRetention = 0.9;

/// Веса FSRS-6 по умолчанию: совпадают в fsrs-rs (`FSRS6_DEFAULT_PARAMETERS`),
/// py-fsrs 6.3.2 и ts-fsrs 5.4.2. Персональная оптимизация — в v1 (ТЗ §4.1).
const List<double> kFsrs6DefaultParameters = [
  0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, //
  0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
  0.0912, 0.0658, 0.1542,
];

/// Порт планировщика FSRS-6 из py-fsrs 6.3.2 (ADR-5): формулы, клампы и
/// округление интервала совпадают, проверено эталонными траекториями
/// (`test/fixtures/srs/py_fsrs_6_3_2.json`). Чистый Dart, без `DateTime.now()`
/// и случайности: один и тот же вход даёт один и тот же результат.
///
/// Отличия от py-fsrs по умолчанию (ADR-5):
/// - один короткий шаг 10 минут и для `learning`, и для `relearning`
///   (в py-fsrs по умолчанию `learning_steps = (1m, 10m)`): номер шага в
///   `user_item_state` не хранится (§7.2), а при одном шаге он всегда 0;
/// - без fuzz: интервал детерминирован (AC7.1).
///
/// Единица планирования — знание (`ItemState`), а не вопрос (ADR-6).
class Scheduler {
  const Scheduler({
    this.desiredRetention = kDesiredRetention,
    this.maximumIntervalDays = 36500,
  });

  final double desiredRetention;
  final int maximumIntervalDays;

  /// Короткий шаг изучения и переизучения.
  static const Duration shortStep = Duration(minutes: 10);

  static const List<double> _w = kFsrs6DefaultParameters;
  static const double _minStability = 0.001;
  static const double _minDifficulty = 1;
  static const double _maxDifficulty = 10;

  static final double _decay = -_w[20];
  static final double _factor = math.pow(0.9, 1 / _decay).toDouble() - 1;

  /// Состояние знания, которое ещё не показывали. Строку в
  /// `user_item_state` для него не пишут, пока не будет первого ответа.
  static ItemState initialState({
    required String itemId,
    required String deckId,
    required DateTime now,
  }) {
    final utc = now.toUtc();
    return ItemState(
      itemId: itemId,
      deckId: deckId,
      due: utc,
      stability: 0,
      difficulty: 0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      state: SrsState.newCard,
      updatedAt: utc,
    );
  }

  /// Новое состояние знания после ответа с оценкой [rating] в момент [now].
  ///
  /// `due`, `lastReview` и `updatedAt` — в UTC. `lastQuestionId` не меняется:
  /// его ставит вызывающий (сессия знает, какой вариант показан).
  ItemState review(ItemState s, Rating rating, DateTime now) {
    final at = now.toUtc();
    final isNew = s.state == SrsState.newCard;
    // Как `timedelta.days` в py-fsrs: целые сутки с прошлого ответа.
    // Отрицательное значение (часы устройств разошлись) ведёт себя как «тот же
    // день» и в эталоне, и здесь.
    final daysSince = isNew || s.lastReview == null
        ? null
        : at.difference(s.lastReview!).inDays;
    final sameDay = daysSince != null && daysSince < 1;

    double stability;
    double difficulty;
    if (isNew) {
      stability = _initialStability(rating);
      difficulty = _clampDifficulty(_initialDifficulty(rating));
    } else {
      // Защита от испорченных данных (например, после синхронизации):
      // формулы определены только для S > 0 и D в [1, 10].
      final prevS = math.max(s.stability, _minStability);
      final prevD = _clampDifficulty(s.difficulty);
      stability = sameDay
          ? _shortTermStability(prevS, rating)
          : _nextStability(
              prevD,
              prevS,
              _retrievability(prevS, math.max(0, daysSince ?? 0)),
              rating,
            );
      difficulty = _nextDifficulty(prevD, rating);
    }

    final SrsState nextState;
    final Duration interval;
    var lapses = s.lapses;
    switch (s.state) {
      case SrsState.review:
        if (rating == Rating.again) {
          nextState = SrsState.relearning;
          interval = shortStep;
          lapses++;
        } else {
          nextState = SrsState.review;
          interval = Duration(days: _nextIntervalDays(stability));
        }
      case SrsState.newCard || SrsState.learning || SrsState.relearning:
        // Один шаг: Again — шаг заново, Hard — 1.5 шага (как в py-fsrs при
        // одном шаге), Good и Easy — выпуск в review.
        switch (rating) {
          case Rating.again:
            nextState = isNew ? SrsState.learning : s.state;
            interval = shortStep;
          case Rating.hard:
            nextState = isNew ? SrsState.learning : s.state;
            interval = shortStep * 1.5;
          case Rating.good || Rating.easy:
            nextState = SrsState.review;
            interval = Duration(days: _nextIntervalDays(stability));
        }
    }

    return s.copyWith(
      due: at.add(interval),
      stability: stability,
      difficulty: difficulty,
      elapsedDays: math.max(0, daysSince ?? 0),
      scheduledDays: interval.inDays,
      reps: s.reps + 1,
      lapses: lapses,
      state: nextState,
      lastReview: at,
      updatedAt: at,
    );
  }

  static double _retrievability(double stability, int elapsedDays) =>
      math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();

  int _nextIntervalDays(double stability) {
    final raw =
        stability / _factor * (math.pow(desiredRetention, 1 / _decay) - 1);
    return raw.round().clamp(1, maximumIntervalDays);
  }

  static double _clampDifficulty(double d) =>
      d.clamp(_minDifficulty, _maxDifficulty);

  static double _initialStability(Rating r) =>
      math.max(_w[r.code - 1], _minStability);

  /// Без клампа: в формуле возврата к среднему py-fsrs 6.3.2 использует
  /// неограниченное значение для Easy (с весами FSRS-6 оно < 1).
  static double _initialDifficulty(Rating r) =>
      _w[4] - math.exp(_w[5] * (r.code - 1)) + 1;

  static double _nextDifficulty(double d, Rating r) {
    final delta = -_w[6] * (r.code - 3);
    final damped = d + (10 - d) * delta / 9;
    final reverted =
        _w[7] * _initialDifficulty(Rating.easy) + (1 - _w[7]) * damped;
    return _clampDifficulty(reverted);
  }

  static double _shortTermStability(double s, Rating r) {
    var increase =
        math.exp(_w[17] * (r.code - 3 + _w[18])) * math.pow(s, -_w[19]);
    if (r != Rating.again) increase = math.max(increase, 1.0);
    return math.max(s * increase, _minStability);
  }

  static double _nextStability(double d, double s, double r, Rating rating) {
    final next = rating == Rating.again
        ? _forgetStability(d, s, r)
        : _recallStability(d, s, r, rating);
    return math.max(next, _minStability);
  }

  static double _forgetStability(double d, double s, double r) {
    final longTerm =
        _w[11] *
        math.pow(d, -_w[12]) *
        (math.pow(s + 1, _w[13]) - 1) *
        math.exp((1 - r) * _w[14]);
    final shortTerm = s / math.exp(_w[17] * _w[18]);
    return math.min(longTerm, shortTerm);
  }

  static double _recallStability(double d, double s, double r, Rating rating) {
    final hardPenalty = rating == Rating.hard ? _w[15] : 1.0;
    final easyBonus = rating == Rating.easy ? _w[16] : 1.0;
    return s *
        (1 +
            math.exp(_w[8]) *
                (11 - d) *
                math.pow(s, -_w[9]) *
                (math.exp((1 - r) * _w[10]) - 1) *
                hardPenalty *
                easyBonus);
  }
}
