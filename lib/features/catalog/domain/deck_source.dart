import 'package:freezed_annotation/freezed_annotation.dart';

part 'deck_source.freezed.dart';
part 'deck_source.g.dart';

/// Открытый источник, на который ссылаются `refs` знаний (ТЗ §5.3).
@freezed
abstract class DeckSource with _$DeckSource {
  const factory DeckSource({
    required String id,
    required String title,
    required String url,

    /// Лицензия источника, например `CC BY-SA 4.0`. Обязательна (R8).
    required String license,
  }) = _DeckSource;

  factory DeckSource.fromJson(Map<String, dynamic> json) =>
      _$DeckSourceFromJson(json);
}
