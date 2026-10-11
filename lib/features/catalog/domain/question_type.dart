import 'package:json_annotation/json_annotation.dart';

/// Формат вопроса (ТЗ M4). Значение в JSON — snake_case: `find_error`.
@JsonEnum(fieldRename: FieldRename.snake)
enum QuestionType { mcq, flip, open, cloze, order, findError }
