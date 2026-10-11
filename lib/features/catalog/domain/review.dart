import 'package:freezed_annotation/freezed_annotation.dart';

part 'review.freezed.dart';
part 'review.g.dart';

/// Статус вычитки знания (ТЗ §5.3, §5.4).
@JsonEnum(fieldRename: FieldRename.snake)
enum ReviewStatus {
  /// Сгенерировано, человек не вычитывал.
  draft,

  /// Верификация или вычитка нашла проблемы, нужна правка.
  needsFix,

  /// Вычитано человеком; только такие знания попадают в релиз.
  approved,
}

@freezed
abstract class Review with _$Review {
  const factory Review({
    required ReviewStatus status,

    /// Кто вычитал. Обязателен при [ReviewStatus.approved].
    String? by,
    String? notes,
  }) = _Review;

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);
}
