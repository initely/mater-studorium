/// Откуда взялась оценка в `review_logs.grade_source` (ТЗ §7.2).
enum GradeSource {
  /// Пользователь оценил сам.
  self,

  /// Автопроверка (mcq, cloze, order, find_error).
  auto,

  /// Оценка LLM по рубрике (`open`).
  llm,

  /// Пользователь изменил предложенную оценку.
  override;

  /// Значение в БД и на сервере.
  String get wire => name;

  static GradeSource fromWire(String wire) =>
      values.firstWhere((s) => s.name == wire);
}
