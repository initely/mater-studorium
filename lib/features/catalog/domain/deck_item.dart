import 'package:freezed_annotation/freezed_annotation.dart';

import 'question.dart';
import 'review.dart';
import 'source_ref.dart';

part 'deck_item.freezed.dart';
part 'deck_item.g.dart';

/// Знание — единица планирования FSRS; у него 1–4 варианта вопроса
/// (ТЗ §4.1). Разборы написаны заранее (ТЗ §4.4).
@freezed
abstract class DeckItem with _$DeckItem {
  const factory DeckItem({
    required String id,
    required String title,
    @Default(<String>[]) List<String> tags,
    required String fact,

    /// «Коротко»: 2–3 предложения.
    required String explanationShort,

    /// «Подробнее»: markdown до ~300 слов.
    required String explanationLong,
    required List<SourceRef> refs,
    required Review review,
    required List<Question> questions,
  }) = _DeckItem;

  factory DeckItem.fromJson(Map<String, dynamic> json) =>
      _$DeckItemFromJson(json);
}
