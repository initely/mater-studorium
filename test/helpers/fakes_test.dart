import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fakes.dart';

void main() {
  test('fake: хранит состояние в памяти', () async {
    final repo = FakeDeckRepository(['ИБ']);
    await repo.addDeck('Сети');
    expect(await repo.deckTitles(), ['ИБ', 'Сети']);
  });

  test('mock: задаём ответ и проверяем вызов', () async {
    final repo = MockDeckRepository();
    when(repo.deckTitles).thenAnswer((_) async => ['ИБ']);
    expect(await repo.deckTitles(), ['ИБ']);
    verify(repo.deckTitles).called(1);
  });
}
