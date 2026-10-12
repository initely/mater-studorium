import '../../catalog/domain/item_ref.dart';
import '../../catalog/domain/local_item.dart';
import '../../catalog/domain/question.dart';

/// Разбор к ответу: тексты и источники, написанные заранее и лежащие в
/// колоде (ТЗ M6, §4.4, ADR-10). LLM в рантайме разборов не создаёт.
class Explanation {
  const Explanation({this.short, this.long, this.sources = const []});

  /// Разбор для вопроса [question] знания [item]. «Коротко» — разбор самого
  /// вопроса, если он переопределён, иначе разбор знания (ТЗ §4.4). Пустые
  /// и состоящие из пробелов тексты считаются отсутствующими.
  factory Explanation.of(LocalItem item, Question question) => Explanation(
    short: _text(question.explanationShort) ?? _text(item.explanationShort),
    long: _text(item.explanationLong),
    sources: item.refs,
  );

  /// «Коротко»: 2–3 предложения; `null` — разбора нет.
  final String? short;

  /// «Подробнее»: markdown; `null` — разбора нет.
  final String? long;

  /// Источники знания (название, лицензия, ссылка, цитата), порядок колоды.
  final List<ItemRef> sources;

  /// Есть ли что показать за кнопкой «Коротко».
  bool get hasShort => short != null;

  /// «Подробнее» открывает развёрнутый текст и/или источники.
  bool get hasLong => long != null || sources.isNotEmpty;

  /// Нет ничего: знание без разбора (пустое состояние панели).
  bool get isEmpty => !hasShort && !hasLong;

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
