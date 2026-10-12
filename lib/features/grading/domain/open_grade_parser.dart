import 'open_grade.dart';

/// Ответ сервера не соответствует контракту `grade-open-answer`.
class OpenGradeFormatException implements Exception {
  const OpenGradeFormatException(this.message);

  final String message;

  @override
  String toString() => 'OpenGradeFormatException($message)';
}

/// Строгий разбор тела 200 (README функции, `contract.ts`).
///
/// Неизвестные поля игнорируются (сервер может расширить контракт). Нарушение
/// контракта (нет обязательного поля, неизвестный вердикт или статус, число
/// вне диапазона) — [OpenGradeFormatException]: лучше самооценка, чем догадка
/// о вердикте. `remaining_quota` и `quota_reset_at` необязательны: клиент
/// показывает их, только если они есть и корректны.
OpenGrade parseOpenGrade(Object? json) {
  final map = _map(json, 'ответ');
  final verdict = GradeVerdict.fromWire(map['verdict']);
  if (verdict == null) throw const OpenGradeFormatException('verdict');
  final score = map['score'];
  if (score is! num || !score.isFinite || score < 0 || score > 1) {
    throw const OpenGradeFormatException('score');
  }
  final origin = switch (map['source']) {
    'llm' => GradeOrigin.llm,
    'rule' => GradeOrigin.rule,
    _ => throw const OpenGradeFormatException('source'),
  };
  final feedback = map['feedback'];
  if (feedback != null && feedback is! String) {
    throw const OpenGradeFormatException('feedback');
  }
  final cached = map['cached'];
  if (cached != null && cached is! bool) {
    throw const OpenGradeFormatException('cached');
  }
  return OpenGrade(
    verdict: verdict,
    score: score.toDouble(),
    points: [
      for (final p in _list(map['points'], 'points'))
        _point(_map(p, 'points[]')),
    ],
    missed: [
      for (final p in _list(map['missed'], 'missed'))
        _missed(_map(p, 'missed[]')),
    ],
    feedback: (feedback as String?) ?? '',
    origin: origin,
    cached: (cached as bool?) ?? false,
    remainingQuota: _quota(map['remaining_quota']),
    quotaResetAt: _time(map['quota_reset_at']),
  );
}

Map<String, Object?> _map(Object? v, String what) {
  if (v is Map) return v.cast<String, Object?>();
  throw OpenGradeFormatException(what);
}

List<Object?> _list(Object? v, String what) {
  if (v == null) return const [];
  if (v is List) return v;
  throw OpenGradeFormatException(what);
}

String _string(Object? v, String what) {
  if (v is String && v.isNotEmpty) return v;
  throw OpenGradeFormatException(what);
}

GradedPoint _point(Map<String, Object?> m) {
  final status = PointStatus.fromWire(m['status']);
  if (status == null) throw const OpenGradeFormatException('points[].status');
  return GradedPoint(id: _string(m['id'], 'points[].id'), status: status);
}

MissedPoint _missed(Map<String, Object?> m) {
  final status = PointStatus.fromWire(m['status']);
  if (status == null || status == PointStatus.hit) {
    throw const OpenGradeFormatException('missed[].status');
  }
  final required = m['required'];
  if (required is! bool) {
    throw const OpenGradeFormatException('missed[].required');
  }
  return MissedPoint(
    id: _string(m['id'], 'missed[].id'),
    text: _string(m['text'], 'missed[].text'),
    status: status,
    required: required,
  );
}

/// Необязательное поле: мусор не ломает разбор, а просто не показывается.
int? _quota(Object? v) {
  if (v is int && v >= 0) return v;
  if (v is double && v.isFinite && v >= 0 && v == v.truncateToDouble()) {
    return v.toInt();
  }
  return null;
}

DateTime? _time(Object? v) {
  if (v is! String) return null;
  return DateTime.tryParse(v)?.toUtc();
}
