import 'dart:convert';
import 'dart:typed_data';

import 'deck.dart';
import 'deck_validator.dart';

/// Результат разбора файла колоды. Только простые данные, поэтому безопасно
/// возвращается из изолята (`compute`).
sealed class DeckParseResult {
  const DeckParseResult();
}

final class DeckParsed extends DeckParseResult {
  const DeckParsed(this.deck);
  final Deck deck;
}

/// Файл не JSON, не по модели или нарушает семантические правила.
final class DeckParseCorrupt extends DeckParseResult {
  const DeckParseCorrupt(this.message);
  final String message;
}

/// `schema_version` выше [kDeckSchemaVersion] (ADR-19): такой файл не читаем.
final class DeckParseSchemaTooNew extends DeckParseResult {
  const DeckParseSchemaTooNew(this.schemaVersion);
  final int schemaVersion;
}

/// Разбирает байты файла колоды: UTF-8 → JSON → [Deck] → [validateDeck]
/// (не release: черновики из каталога клиент не отсекает). Не бросает.
///
/// Чистая функция верхнего уровня, чтобы её можно было отдать `compute`.
DeckParseResult parseDeckBytes(Uint8List bytes) {
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (e) {
    return DeckParseCorrupt('не JSON: ${e.message}');
  } on Object catch (e) {
    // Например, StackOverflowError на патологически вложенном файле.
    return DeckParseCorrupt('файл не разбирается: ${e.runtimeType}');
  }
  if (json is! Map<String, dynamic>) {
    return const DeckParseCorrupt('корень файла не объект');
  }

  // Версию формата смотрим до разбора: колода новой схемы могла бы не
  // разобраться и выглядела бы «повреждённой» (ADR-19).
  final schemaVersion = json['schema_version'];
  if (schemaVersion is int && schemaVersion > kDeckSchemaVersion) {
    return DeckParseSchemaTooNew(schemaVersion);
  }

  final Deck deck;
  try {
    deck = Deck.fromJson(json);
  } on Object catch (e) {
    return DeckParseCorrupt('не по модели колоды: $e');
  }
  final issues = validateDeck(deck);
  if (issues.isNotEmpty) {
    final shown = issues.take(3).join('; ');
    return DeckParseCorrupt(
      'нарушены правила колоды (${issues.length}): $shown',
    );
  }
  return DeckParsed(deck);
}
