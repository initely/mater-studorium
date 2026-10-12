import '../../catalog/domain/local_deck.dart';
import 'deck_progress.dart';

/// Скачанная колода и прогресс по ней: данные экрана колоды.
class DeckDetails {
  const DeckDetails({required this.deck, required this.progress});

  final LocalDeck deck;
  final DeckProgress progress;
}
