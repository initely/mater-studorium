import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_ref.freezed.dart';
part 'source_ref.g.dart';

/// Привязка факта к источнику (ТЗ §5.3).
///
/// URL не хранится: он берётся из `DeckSource` по [sourceId], поэтому
/// ссылка вне `sources` невозможна (ADR-18).
@freezed
abstract class SourceRef with _$SourceRef {
  const factory SourceRef({
    required String sourceId,

    /// Дословная цитата со страницы источника; её ищет `check_links`.
    required String quote,

    /// Страница недоступна скрипту (paywall и т.п.): `check_links` проверяет
    /// только ответ 200.
    @Default(false) bool quoteUnverifiable,
  }) = _SourceRef;

  factory SourceRef.fromJson(Map<String, dynamic> json) =>
      _$SourceRefFromJson(json);
}
