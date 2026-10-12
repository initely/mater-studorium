import '../../grading/domain/open_grade.dart';
import '../../srs/domain/rating.dart';
import 'report_reason.dart';
import 'report_text.dart';

/// Что спорно в «не согласен с оценкой ИИ» (ТЗ M11, ADR-33): ответ
/// пользователя, вердикт модели и оценка, которую он считает верной.
/// Рубрика, эталон и комментарий модели не копируются: куратор берёт их из
/// колоды по версии отчёта и может повторить оценку.
class GradingDisagreement {
  const GradingDisagreement({
    required this.answerText,
    required this.verdict,
    required this.userRating,
    this.llmScore,
  });

  /// Ответ пользователя (до 2000 знаков).
  final String answerText;

  /// Вердикт модели; `unsure` не бывает: его оценивает сам пользователь.
  final GradeVerdict verdict;

  /// Балл модели 0…1, если сервер его вернул.
  final double? llmScore;

  /// Оценка, которую пользователь поставил вместо предложенной.
  final Rating userRating;
}

/// Балл до 4 знаков: 1e-50 и подобное сервер при разборе JSON отвергал бы
/// (`22003`), а куратору нужна не точность, а порядок величины. Нечисловое
/// (NaN, ∞) оставляется как есть: `isValidReport` такой отчёт отвергнет.
double? _roundScore(double? score) {
  if (score == null || !score.isFinite) return score;
  return (score * 10000).round() / 10000;
}

/// Жалоба или «не согласен» (ТЗ M11, §7.2): запись очереди отправки и тело
/// RPC `submit_report`. Значения приводятся к границам сервера при создании:
/// тексты очищаются и обрезаются (`sanitizeReportText`).
///
/// [id] — клиентский uuid: повторная отправка идемпотентна.
class Report {
  const Report._({
    required this.id,
    required this.deckId,
    required this.deckVersion,
    required this.questionId,
    required this.reason,
    this.comment,
    this.questionText,
    this.disagreement,
  });

  /// Жалоба на вопрос с причиной из [ReportReason.choosable].
  factory Report.question({
    required String id,
    required String deckId,
    required int deckVersion,
    required String questionId,
    required ReportReason reason,
    String? comment,
    String? questionText,
  }) {
    assert(reason != ReportReason.gradingDisagree);
    return Report._(
      id: id,
      deckId: deckId,
      deckVersion: deckVersion,
      questionId: questionId,
      reason: reason,
      comment: sanitizeReportText(comment, max: kMaxReportCommentChars),
      questionText: sanitizeReportText(
        questionText,
        max: kMaxReportQuestionTextChars,
      ),
    );
  }

  /// «Не согласен с оценкой»: причина `grading_disagree`. Ответ, пустой после
  /// очистки, остаётся пустым: такой отчёт сервер не принял бы, и
  /// `isValidReport` скажет «нет».
  factory Report.disagreement({
    required String id,
    required String deckId,
    required int deckVersion,
    required String questionId,
    required String answerText,
    required GradeVerdict verdict,
    required Rating userRating,
    double? llmScore,
    String? comment,
    String? questionText,
  }) => Report._(
    id: id,
    deckId: deckId,
    deckVersion: deckVersion,
    questionId: questionId,
    reason: ReportReason.gradingDisagree,
    comment: sanitizeReportText(comment, max: kMaxReportCommentChars),
    questionText: sanitizeReportText(
      questionText,
      max: kMaxReportQuestionTextChars,
    ),
    disagreement: GradingDisagreement(
      answerText:
          sanitizeReportText(answerText, max: kMaxReportAnswerChars) ?? '',
      verdict: verdict,
      llmScore: _roundScore(llmScore),
      userRating: userRating,
    ),
  );

  /// Разбор из `outbox.payload_json` (тот же вид, что тело RPC). Неверная
  /// форма — `FormatException`: такую запись отправить нельзя никогда.
  factory Report.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('отчёт: ожидался объект');
    try {
      final reason = ReportReason.fromWire(json['reason']);
      if (reason == null) {
        throw const FormatException('отчёт: неизвестная причина');
      }
      final id = json['id'] as String;
      final deckId = json['deck_id'] as String;
      final deckVersion = (json['deck_version'] as num).toInt();
      final questionId = json['question_id'] as String;
      final comment = json['comment'] as String?;
      final questionText = json['question_text'] as String?;
      if (reason != ReportReason.gradingDisagree) {
        return Report.question(
          id: id,
          deckId: deckId,
          deckVersion: deckVersion,
          questionId: questionId,
          reason: reason,
          comment: comment,
          questionText: questionText,
        );
      }
      final verdict = GradeVerdict.fromWire(json['llm_verdict']);
      if (verdict == null || verdict == GradeVerdict.unsure) {
        throw const FormatException('отчёт: неизвестный вердикт');
      }
      return Report.disagreement(
        id: id,
        deckId: deckId,
        deckVersion: deckVersion,
        questionId: questionId,
        answerText: json['answer_text'] as String,
        verdict: verdict,
        userRating: Rating.fromCode((json['user_rating'] as num).toInt()),
        llmScore: (json['llm_score'] as num?)?.toDouble(),
        comment: comment,
        questionText: questionText,
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('отчёт: неверная форма ($e)');
    }
  }

  final String id;
  final String deckId;
  final int deckVersion;
  final String questionId;
  final ReportReason reason;

  /// Комментарий пользователя (до 500 знаков) или `null`.
  final String? comment;

  /// Текст вопроса для куратора (до 600 знаков): `reports_inbox` показывает
  /// его рядом с жалобой.
  final String? questionText;

  /// Только у `grading_disagree`.
  final GradingDisagreement? disagreement;

  /// Тело RPC `submit_report` и `outbox.payload_json`.
  Map<String, Object?> toJson() => {
    'id': id,
    'deck_id': deckId,
    'deck_version': deckVersion,
    'question_id': questionId,
    'reason': reason.wire,
    'comment': comment,
    'question_text': questionText,
    if (disagreement case final d?) ...{
      'answer_text': d.answerText,
      'llm_verdict': d.verdict.name,
      'llm_score': d.llmScore,
      'user_rating': d.userRating.code,
    },
  };

  @override
  String toString() => 'Report($id, ${reason.wire}, $questionId)';
}
