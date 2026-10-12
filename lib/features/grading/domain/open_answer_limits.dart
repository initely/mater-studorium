/// Границы ответа на `open` по контракту `grade-open-answer` (ТЗ §4.2, ADR-31).
///
/// Длина считается в единицах UTF-16 (`String.length`), как на сервере
/// (`MAX_ANSWER_CHARS` в `_shared/grading.ts` Edge Function).
const int kMaxOpenAnswerChars = 2000;

/// Ответ короче этого числа символов сервер оценивает как `incorrect` без
/// модели (ТЗ §4.2, п. 1); клиент не тратит на него запрос.
const int kMinOpenAnswerChars = 3;

/// Ответ слишком короткий для вызова модели (после обрезки пробелов по краям).
///
/// Сервер нормализует ввод жёстче (убирает невидимые символы), поэтому
/// «достаточно длинный» по этой проверке ответ он всё равно может счесть
/// коротким и вернёт `source: rule`; это допустимо. Клиентская проверка
/// только экономит запрос на заведомо коротком ответе.
bool isTooShortOpenAnswer(String answer) =>
    answer.trim().runes.length < kMinOpenAnswerChars;

/// Обрезает [text] до [kMaxOpenAnswerChars] единиц UTF-16, не разрывая
/// суррогатную пару.
String clampOpenAnswer(String text) {
  if (text.length <= kMaxOpenAnswerChars) return text;
  var end = kMaxOpenAnswerChars;
  final last = text.codeUnitAt(end - 1);
  // Верхняя половина пары на границе: пара целиком не помещается.
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return text.substring(0, end);
}
