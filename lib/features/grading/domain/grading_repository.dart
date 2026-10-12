import 'open_grade.dart';

/// Как введён ответ (`input_mode` контракта): `voice` — текст диктовки, модель
/// прощает ошибки распознавания (ТЗ §4.2).
enum AnswerInputMode {
  text,
  voice;

  String get wire => name;
}

/// Запрос оценки. Только то, что разрешает контракт (ТЗ §5.2, ADR-31):
/// рубрику, эталон, язык и модель сервер берёт из своей копии колоды, лишнее
/// поле он отклоняет (`400 unknown_field`).
class GradeRequest {
  const GradeRequest({
    required this.deckId,
    required this.deckVersion,
    required this.questionId,
    required this.answerText,
    required this.inputMode,
  });

  final String deckId;
  final int deckVersion;
  final String questionId;

  /// До 2000 символов UTF-16.
  final String answerText;
  final AnswerInputMode inputMode;
}

/// Оценка открытого ответа на сервере (Edge Function `grade-open-answer`).
/// Реализация в `data/`.
///
/// Бросает только типизированные ошибки `core/errors/`: `AuthError` (любой
/// 401 или нет сессии), `QuotaExceededError` (429, с временем сброса),
/// `NetworkError` (сети нет, таймаут, 5xx, 502, 504), `RequestRejectedError`
/// (400, 403, 404, 413), `UnexpectedError` (ответ не по контракту).
abstract interface class GradingRepository {
  Future<OpenGrade> grade(GradeRequest request);
}
