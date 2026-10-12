/// Причина жалобы (ТЗ M11, §7.2). [wire] — значение в БД и на сервере
/// (`reports.reason`, `0005_reports.sql`).
enum ReportReason {
  wrongAnswer('wrong_answer'),
  unclear('unclear'),
  typo('typo'),
  badSource('bad_source'),
  other('other'),

  /// «Не согласен с оценкой ИИ»: пользователь не выбирает её в шторке
  /// жалобы, report создаёт кнопка «Не согласен».
  gradingDisagree('grading_disagree');

  const ReportReason(this.wire);

  final String wire;

  /// Причины шторки «Пожаловаться» в порядке показа (M11).
  static const choosable = [wrongAnswer, unclear, typo, badSource, other];

  static ReportReason? fromWire(Object? wire) {
    for (final v in values) {
      if (v.wire == wire) return v;
    }
    return null;
  }
}
