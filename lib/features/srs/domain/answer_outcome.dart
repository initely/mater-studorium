/// Итог проверки ответа — строки таблицы «источник → предлагаемая оценка»
/// (ТЗ §4.1). Грейдеры (T13, T16, T27–T29) переводят свой результат в одно
/// из этих значений.
enum AnswerOutcome {
  /// Автопроверка (`mcq`, `cloze`, `order`, `find_error`): верно.
  autoCorrect,

  /// Автопроверка: неверно.
  autoIncorrect,

  /// `order`: одна перестановка соседних шагов.
  orderAdjacentSwap,

  /// `cloze`: ответ принят с опечаткой.
  clozeTypo,

  /// `open`: вердикт LLM `correct`.
  llmCorrect,

  /// `open`: вердикт LLM `partial`.
  llmPartial,

  /// `open`: вердикт LLM `incorrect`.
  llmIncorrect,

  /// `open`: `unsure`, ошибка, таймаут, офлайн или лимит — самооценка
  /// с эталоном (ТЗ §4.2, AC5.2).
  llmUnavailable,

  /// `flip`: пользователь оценивает себя сам.
  flip,
}
