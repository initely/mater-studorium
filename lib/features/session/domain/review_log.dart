import 'package:freezed_annotation/freezed_annotation.dart';

import '../../catalog/domain/question_type.dart';
import '../../srs/domain/rating.dart';
import 'grade_source.dart';

part 'review_log.freezed.dart';

/// Запись об одном ответе (ТЗ §7.2 `review_logs`). Без `user_id` и
/// `synced_at`: их ведёт хранилище.
@freezed
abstract class ReviewLog with _$ReviewLog {
  const factory ReviewLog({
    /// uuid, создаётся на клиенте: повторная отправка идемпотентна.
    required String id,
    required String deckId,
    required int deckVersion,
    required String itemId,
    required String questionId,
    required QuestionType questionType,
    required Rating rating,
    required GradeSource gradeSource,
    double? llmScore,
    String? answerText,
    required int durationMs,

    /// UTC.
    required DateTime reviewedAt,
  }) = _ReviewLog;
}
