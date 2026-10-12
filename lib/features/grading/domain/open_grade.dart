/// Вердикт сервера по открытому ответу (ТЗ §4.2, п. 6). Считает сервер;
/// клиент пороги не знает и не пересчитывает.
enum GradeVerdict {
  correct,
  partial,
  incorrect,

  /// Модель не уверена или её ответ не разобран: самооценка.
  unsure;

  static GradeVerdict? fromWire(Object? wire) {
    for (final v in values) {
      if (v.name == wire) return v;
    }
    return null;
  }
}

/// Статус пункта рубрики (✓ ½ ✗ на экране).
enum PointStatus {
  hit,
  partial,
  miss;

  static PointStatus? fromWire(Object? wire) {
    for (final v in values) {
      if (v.name == wire) return v;
    }
    return null;
  }
}

/// Кто оценил: модель (в том числе из кэша) или правило «ответ короче
/// 3 символов» (ТЗ §4.2, п. 1).
enum GradeOrigin { llm, rule }

/// Статус одного пункта рубрики в порядке рубрики.
class GradedPoint {
  const GradedPoint({required this.id, required this.status});

  final String id;
  final PointStatus status;
}

/// Упущенный или раскрытый частично пункт: текст берёт сервер из рубрики
/// колоды (ADR-28, п. 6), не модель.
class MissedPoint {
  const MissedPoint({
    required this.id,
    required this.text,
    required this.status,
    required this.required,
  });

  final String id;
  final String text;

  /// `miss` или `partial`.
  final PointStatus status;
  final bool required;
}

/// Ответ `grade-open-answer` (200), без рубрики и эталона: их в ответе нет
/// (ТЗ §5.2, ADR-31).
class OpenGrade {
  const OpenGrade({
    required this.verdict,
    required this.score,
    required this.points,
    required this.missed,
    required this.feedback,
    required this.origin,
    required this.cached,
    this.remainingQuota,
    this.quotaResetAt,
  });

  final GradeVerdict verdict;

  /// 0…1.
  final double score;
  final List<GradedPoint> points;
  final List<MissedPoint> missed;

  /// Комментарий модели или `''`.
  final String feedback;
  final GradeOrigin origin;
  final bool cached;

  /// Сколько вызовов модели осталось на сегодня (UTC-сутки); `null`, если
  /// сервер не прислал.
  final int? remainingQuota;

  /// Когда лимит обнулится (UTC); `null`, если сервер не прислал.
  final DateTime? quotaResetAt;
}
