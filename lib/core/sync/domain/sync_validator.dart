// Проверка и нормализация строк перед отправкой. Правила совпадают с
// ограничениями таблиц в серверной миграции 0003_sync.sql: сервер отклоняет
// пакет целиком, поэтому строку, которую он заведомо не примет, клиент не
// отправляет, а оставляет локально (иначе одна битая строка навсегда
// остановила бы отправку всех остальных). При изменении правил — менять оба
// места и тест test/core/sync/sync_rules_test.dart.
import 'dart:math' as math;

import '../../../features/session/domain/review_log.dart';
import '../../../features/srs/domain/item_state.dart';

final _id = RegExp(r'^[a-z0-9]+([._-][a-z0-9]+)*$');
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _minTime = DateTime.utc(1970);
final _maxTime = DateTime.utc(2200);

/// Наибольшая длительность ответа на сервере (сутки).
const kMaxDurationMs = 86400000;

/// Наибольшая длина текста ответа на сервере.
const kMaxAnswerTextLength = 4000;

bool _isId(String s, int maxLength) => s.length <= maxLength && _id.hasMatch(s);

bool _inTime(DateTime t) => !t.isBefore(_minTime) && t.isBefore(_maxTime);

bool _finiteIn(double v, double min, double max) =>
    v.isFinite && v >= min && v <= max;

/// Состояние, которое примет сервер.
bool isValidStateForPush(ItemState s) =>
    _isId(s.itemId, 128) &&
    _isId(s.deckId, 64) &&
    _inTime(s.due) &&
    _finiteIn(s.stability, 0, 1e9) &&
    _finiteIn(s.difficulty, 0, 10) &&
    s.elapsedDays >= 0 &&
    s.elapsedDays <= 100000 &&
    s.scheduledDays >= 0 &&
    s.scheduledDays <= 100000 &&
    s.reps >= 0 &&
    s.reps <= 1000000 &&
    s.lapses >= 0 &&
    s.lapses <= s.reps &&
    (s.lastReview == null || _inTime(s.lastReview!)) &&
    (s.lastQuestionId == null || _isId(s.lastQuestionId!, 128)) &&
    s.updatedAt.isBefore(_maxTime);

/// Лог в виде, который примет сервер, или `null`, если такой лог сервер не
/// примет никогда. Длительность зажимается в `[0, сутки]`, текст ответа
/// обрезается до [kMaxAnswerTextLength]: это поля для статистики, а не для
/// расписания, и долгий (вкладку оставили открытой) ответ не должен навсегда
/// остаться неотправленным. Локальная запись не меняется.
ReviewLog? normalizeLogForPush(ReviewLog l) {
  final valid =
      _uuid.hasMatch(l.id) &&
      _isId(l.deckId, 64) &&
      l.deckVersion >= 1 &&
      l.deckVersion <= 1000000 &&
      _isId(l.itemId, 128) &&
      _isId(l.questionId, 128) &&
      (l.llmScore == null || _finiteIn(l.llmScore!, 0, 1)) &&
      _inTime(l.reviewedAt);
  if (!valid) return null;
  return l.copyWith(
    durationMs: math.min(math.max(l.durationMs, 0), kMaxDurationMs),
    answerText: _truncate(l.answerText),
  );
}

/// Обрезка по UTF-16 (не длиннее, чем `char_length` в Postgres), не
/// разрывая суррогатную пару.
String? _truncate(String? text) {
  if (text == null || text.length <= kMaxAnswerTextLength) return text;
  var end = kMaxAnswerTextLength;
  final last = text.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return text.substring(0, end);
}
