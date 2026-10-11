import 'dart:convert';
import 'dart:io';

/// Корректная колода со всеми типами вопросов, все знания approved.
const goodDeckPath = 'test/fixtures/decks/good.json';

/// Образец формата из `content/decks/`.
const sampleDeckPath = 'content/decks/sample.json';

const deckSchemaPath = 'content/schema/deck.schema.json';

/// Свежая копия JSON-файла: тесты мутируют её, не мешая друг другу.
/// Пути — от корня репозитория (`flutter test` запускается оттуда).
Map<String, dynamic> readJsonFile(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Узел JSON по JSON Pointer (`/items/0/questions/1/payload`) — для мутаций.
Map<String, dynamic> nodeAt(Map<String, dynamic> json, String pointer) {
  Object? node = json;
  for (final key in pointer.split('/').skip(1)) {
    node = switch (node) {
      final Map<String, dynamic> map => map[key],
      final List<dynamic> list => list[int.parse(key)],
      _ => throw ArgumentError('Нет узла $pointer'),
    };
  }
  return node! as Map<String, dynamic>;
}
