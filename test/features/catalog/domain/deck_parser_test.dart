import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/deck_parser.dart';

import '../../../helpers/deck_fixtures.dart';

Uint8List _bytes(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  test('корректная колода разбирается', () {
    final result = parseDeckBytes(
      Uint8List.fromList(File(goodDeckPath).readAsBytesSync()),
    );
    expect(result, isA<DeckParsed>());
    expect((result as DeckParsed).deck.items, hasLength(3));
  });

  test('черновик (review.status = draft) клиент не отсекает', () {
    final result = parseDeckBytes(
      Uint8List.fromList(File(sampleDeckPath).readAsBytesSync()),
    );
    expect(result, isA<DeckParsed>());
  });

  test('schema_version выше поддерживаемой: DeckParseSchemaTooNew', () {
    final json = readJsonFile(goodDeckPath)
      ..['schema_version'] = kDeckSchemaVersion + 1
      // Колода новой схемы может не разбираться: версия проверяется первой.
      ..remove('items');
    final result = parseDeckBytes(_bytes(json));
    expect(
      result,
      isA<DeckParseSchemaTooNew>().having(
        (r) => r.schemaVersion,
        'schemaVersion',
        kDeckSchemaVersion + 1,
      ),
    );
  });

  for (final (name, bytes) in [
    ('не JSON', Uint8List.fromList(utf8.encode('{'))),
    ('не UTF-8', Uint8List.fromList([0xc3, 0x28])),
    ('не объект', _bytes(<Object>[])),
    ('нет полей модели', _bytes(<String, Object>{'schema_version': 1})),
  ]) {
    test('$name: DeckParseCorrupt, без исключения', () {
      expect(parseDeckBytes(bytes), isA<DeckParseCorrupt>());
    });
  }

  test('патологически вложенный файл: DeckParseCorrupt, без исключения', () {
    final nested = Uint8List.fromList(utf8.encode('[' * 2000000));
    expect(parseDeckBytes(nested), isA<DeckParseCorrupt>());
  });

  test('нарушение семантики: сообщение называет правило', () {
    final json = readJsonFile(goodDeckPath);
    (json['items'] as List<dynamic>).add(
      (json['items'] as List<dynamic>).first,
    );
    final result = parseDeckBytes(_bytes(json));
    expect(
      result,
      isA<DeckParseCorrupt>().having(
        (r) => r.message,
        'message',
        contains('повторяется'),
      ),
    );
  });
}
