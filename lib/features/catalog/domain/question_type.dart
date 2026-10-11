import 'package:json_annotation/json_annotation.dart';

/// Формат вопроса (ТЗ M4). Значение в JSON — snake_case: `find_error`.
@JsonEnum(fieldRename: FieldRename.snake)
enum QuestionType {
  mcq,
  flip,
  open,
  cloze,
  order,
  findError;

  /// Значение в JSON колоды, локальной БД и на сервере (`find_error`).
  String get wire =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  static QuestionType fromWire(String wire) =>
      values.firstWhere((t) => t.wire == wire);
}
