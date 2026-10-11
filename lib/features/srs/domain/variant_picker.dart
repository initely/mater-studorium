import 'dart:math' as math;

import '../../catalog/domain/question.dart';
import '../../catalog/domain/question_type.dart';
import 'item_state.dart';
import 'srs_state.dart';

/// Выбирает, каким вариантом вопроса показать знание (ТЗ §4.1, AC7.2).
///
/// Правила по убыванию силы:
/// 1. Скрытые по жалобам вопросы не показываются никогда. Не осталось
///    ни одного — `null`: знание пропускается (в очередь такие знания и так
///    не попадают, см. `ReviewDao`).
/// 2. Вариант один — берём его.
/// 3. Пока `S < 3 дня` (и у нового знания), `open` не показываем.
/// 4. Первый показ: `flip`, иначе `mcq`, иначе любой.
/// 5. Дальше: тип отличается от прошлого показа; из таких — тот, что дольше
///    всех не показывался (ни разу не показанный — самый «давний»).
///
/// Если правило 3 или 5 не оставляет кандидатов, оно ослабляется (сначала 5,
/// потом 3), а не бросает исключение. Равные кандидаты разбиваются
/// случайно — только через переданный [math.Random], поэтому выбор
/// детерминирован при фиксированном seed.
class VariantPicker {
  const VariantPicker(this._random);

  final math.Random _random;

  /// Порог стабильности (в днях), ниже которого `open` не показывается.
  static const double openMinStabilityDays = 3;

  /// [questions] — все вопросы знания (в порядке колоды); [state] — `null`
  /// или `SrsState.newCard`, если знание ещё не показывали; [lastShownAt] —
  /// когда каждый вопрос показывался в последний раз (из `review_logs`),
  /// нет ключа — ни разу.
  Question? pick({
    required List<Question> questions,
    required ItemState? state,
    required Set<String> hiddenQuestionIds,
    Map<String, DateTime> lastShownAt = const {},
  }) {
    final visible = [
      for (final q in questions)
        if (!hiddenQuestionIds.contains(q.id)) q,
    ];
    if (visible.length <= 1) return visible.firstOrNull;

    final seen = state?.state == SrsState.newCard ? null : state;
    final stability = seen?.stability ?? 0;
    final pool = _nonEmptyOr([
      for (final q in visible)
        if (q.type != QuestionType.open || stability >= openMinStabilityDays) q,
    ], visible);

    if (seen == null) {
      for (final type in const [QuestionType.flip, QuestionType.mcq]) {
        final ofType = [
          for (final q in pool)
            if (q.type == type) q,
        ];
        if (ofType.isNotEmpty) return _any(ofType);
      }
      return _any(pool);
    }

    final lastType = [
      for (final q in questions)
        if (q.id == seen.lastQuestionId) q.type,
    ].firstOrNull;
    final candidates = _nonEmptyOr([
      for (final q in pool)
        if (q.type != lastType) q,
    ], pool);

    final neverShown = [
      for (final q in candidates)
        if (!lastShownAt.containsKey(q.id)) q,
    ];
    if (neverShown.isNotEmpty) return _any(neverShown);

    int shownAt(Question q) => lastShownAt[q.id]!.microsecondsSinceEpoch;
    final oldest = candidates.map(shownAt).reduce(math.min);
    return _any([
      for (final q in candidates)
        if (shownAt(q) == oldest) q,
    ]);
  }

  static List<Question> _nonEmptyOr(
    List<Question> preferred,
    List<Question> fallback,
  ) => preferred.isEmpty ? fallback : preferred;

  Question _any(List<Question> from) => from[_random.nextInt(from.length)];
}
