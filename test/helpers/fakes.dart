import 'package:mocktail/mocktail.dart';

// ПРИМЕР шаблона для тестов, не продуктовый код. Реальные репозитории живут в
// features/<f>/data/ за интерфейсом из domain/; здесь тот же приём в миниатюре.

/// Интерфейс репозитория (в проекте — в `domain/`).
abstract interface class ExampleDeckRepository {
  Future<List<String>> deckTitles();
  Future<void> addDeck(String title);
}

/// Fake: рабочая in-memory реализация. Подходит, когда важно поведение
/// (добавили, потом прочитали). Подставляется через `overrides` провайдера.
class FakeDeckRepository implements ExampleDeckRepository {
  FakeDeckRepository([Iterable<String> initial = const []])
    : _titles = [...initial];

  final List<String> _titles;

  @override
  Future<List<String>> deckTitles() async => List.unmodifiable(_titles);

  @override
  Future<void> addDeck(String title) async => _titles.add(title);
}

/// Mock (mocktail): когда нужно проверить вызовы или задать ответ точечно.
class MockDeckRepository extends Mock implements ExampleDeckRepository {}
