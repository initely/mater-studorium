import '../../catalog/domain/local_item.dart';
import '../../catalog/domain/question.dart';

/// Содержимое знания для очереди: само знание, версия его колоды и
/// видимые (не скрытые по жалобам) вопросы в порядке колоды.
class ItemContent {
  const ItemContent({
    required this.item,
    required this.deckVersion,
    required this.questions,
  });

  final LocalItem item;
  final int deckVersion;

  /// Не пуст: знания без видимых вопросов репозиторий не возвращает.
  final List<Question> questions;
}
