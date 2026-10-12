import 'report.dart';
import 'report_reason.dart';
import 'report_text.dart';

// Правила совпадают с ограничениями таблицы reports в миграции
// 0005_reports.sql: сервер отклоняет такую жалобу целиком и навсегда, поэтому
// клиент её не отправляет (иначе «ядовитая» запись возвращалась бы в очередь
// при каждом прогоне, урок T17). При изменении правил менять оба места и
// тест test/features/reports/domain/report_test.dart.
final _id = RegExp(r'^[a-z0-9]+([._-][a-z0-9]+)*$');
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool _isId(String s, int maxLength) => s.length <= maxLength && _id.hasMatch(s);

/// Жалоба в виде, который примет сервер (не считая лимитов и существования
/// колоды: это решает сервер).
bool isValidReport(Report r) {
  if (!_uuid.hasMatch(r.id) ||
      !_isId(r.deckId, 64) ||
      r.deckVersion < 1 ||
      r.deckVersion > 1000000 ||
      !_isId(r.questionId, 128)) {
    return false;
  }
  if ((r.comment?.length ?? 0) > kMaxReportCommentChars ||
      (r.questionText?.length ?? 0) > kMaxReportQuestionTextChars) {
    return false;
  }
  final d = r.disagreement;
  if (r.reason == ReportReason.gradingDisagree) {
    if (d == null ||
        d.answerText.isEmpty ||
        d.answerText.length > kMaxReportAnswerChars) {
      return false;
    }
    final score = d.llmScore;
    return score == null || (score.isFinite && score >= 0 && score <= 1);
  }
  return d == null;
}
