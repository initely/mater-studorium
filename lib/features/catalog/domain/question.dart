import 'package:freezed_annotation/freezed_annotation.dart';

import 'question_payload.dart';
import 'question_type.dart';

part 'question.freezed.dart';
part 'question.g.dart';

/// Вариант вопроса к знанию (ТЗ §7.1).
///
/// В JSON `type` лежит на уровне вопроса, а `payload` без дискриминатора:
/// `{"id": "...", "type": "mcq", "prompt": "...", "payload": {...}}`.
/// В Dart [payload] — sealed-объединение [QuestionPayload] с ключом `type`;
/// при чтении `type` подмешивается в payload, при записи убирается
/// (ADR-18). [type] дублирует `payload.type` ради плоского JSON и колонки
/// `type` в локальной БД; согласованность проверяет assert.
@freezed
abstract class Question with _$Question {
  // Не const: assert вызывает геттер, а это не константное выражение.
  @Assert('payload.type == type', 'type must match payload variant')
  factory Question({
    required String id,
    required QuestionType type,

    /// Текст вопроса. Для `cloze` содержит плейсхолдеры `{{id}}`.
    required String prompt,

    /// Переопределяет `explanation_short` знания для этого вопроса (ТЗ §4.4).
    String? explanationShort,
    @JsonKey(readValue: _readPayload, toJson: _payloadToJson)
    required QuestionPayload payload,
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}

/// Переносит `type` вопроса внутрь payload, чтобы сработал дискриминатор
/// [QuestionPayload.fromJson].
Object? _readPayload(Map<dynamic, dynamic> json, String key) {
  final payload = json[key];
  if (payload is! Map) return payload;
  return <String, dynamic>{
    for (final entry in payload.entries) entry.key as String: entry.value,
    'type': json['type'],
  };
}

Map<String, dynamic> _payloadToJson(QuestionPayload payload) =>
    payload.toJson()..remove('type');
