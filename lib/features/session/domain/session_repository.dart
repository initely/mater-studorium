import '../../catalog/domain/local_item.dart';
import '../../reports/domain/report.dart';
import '../../srs/domain/item_state.dart';
import 'item_content.dart';
import 'review_log.dart';

/// Хранилище для сессии. Реализация — в `data/` поверх локальной БД; `domain/`
/// о БД не знает. Все методы работают от имени текущего пользователя.
/// `dueStates` и `newItems` не возвращают знания `retired` и знания без
/// видимых вопросов.
abstract interface class SessionRepository {
  /// Состояния знаний с `due <= now` по возрастанию `due` (при равенстве — по
  /// `itemId`). [deckIds] `null` — все колоды.
  Future<List<ItemState>> dueStates({
    required DateTime now,
    Set<String>? deckIds,
  });

  /// Знания без состояния (ни разу не показанные) в порядке колоды;
  /// не больше [limit].
  Future<List<LocalItem>> newItems({Set<String>? deckIds, required int limit});

  /// Сколько знаний впервые показаны в `[from, to)` (UTC).
  Future<int> countNewItemsFirstShown({
    required DateTime from,
    required DateTime to,
  });

  /// Ближайшее `due` строго после [after] или `null`.
  Future<DateTime?> nextDue({required DateTime after, Set<String>? deckIds});

  /// Содержимое знаний; ключ — `itemId`. Знания, которых нет или у которых
  /// нет видимых вопросов, в карте отсутствуют (`retired` здесь не
  /// проверяется: `ids` приходят из `dueStates` и `newItems`).
  Future<Map<String, ItemContent>> contentFor(Set<String> itemIds);

  /// `question_id` -> когда вопрос показывали в последний раз; вопроса нет
  /// в карте — не показывали.
  Future<Map<String, DateTime>> lastShownAt(Set<String> itemIds);

  /// Пишет ответ: [log] и новое [state] одной транзакцией (CLAUDE.md,
  /// «Как не ломать архитектуру», п. 4). Если пользователь не согласен с
  /// оценкой ИИ, [report] (`grading_disagree`, ТЗ M11) ставится в очередь
  /// отправки в той же транзакции: оценка и жалоба на неё не расходятся.
  /// Ошибка хранилища — `LocalStorageError`, ничего не записано.
  Future<void> recordReview({
    required ReviewLog log,
    required ItemState state,
    Report? report,
  });
}
