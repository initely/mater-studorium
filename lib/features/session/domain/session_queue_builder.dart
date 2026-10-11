import 'dart:math' as math;

import '../../srs/domain/item_state.dart';
import '../../srs/domain/scheduler.dart';
import '../../srs/domain/variant_picker.dart';
import 'local_day.dart';
import 'session_item.dart';
import 'session_queue.dart';
import 'session_repository.dart';
import 'session_settings.dart';

/// Строит очередь сессии (ТЗ M3, §4.1, AC3.1).
///
/// Порядок и состав:
/// 1. Повторения: знания с `due <= now` по возрастанию `due`. Знания с
///    одинаковым `due` перемешиваются через [math.Random] (иначе порядок
///    равных определял бы `item_id`). Приоритет `due` перемешиванием не
///    нарушается.
/// 2. Новые знания — после всех повторений, в порядке колоды, не больше
///    `newPerDay` минус сколько новых знаний уже впервые показано за
///    локальные сутки пользователя (по `review_logs`), плюс `extraNew`
///    («Взять новые» по просьбе пользователя, ТЗ AC3.3, §8.5).
/// 3. Всего не больше `sessionSize`: повторения занимают места первыми.
/// 4. Одно знание — не больше одного раза за сессию, один вопрос на знание:
///    вариант выбирает [VariantPicker] (скрытые вопросы не попадают).
///
/// Время, [math.Random] и часовой пояс приходят снаружи, поэтому результат
/// при тех же входах и том же seed одинаков.
class SessionQueueBuilder {
  SessionQueueBuilder({
    required this._repository,
    required math.Random random,
    required this._utcOffsetAt,
  }) : _random = random,
       _picker = VariantPicker(random);

  final SessionRepository _repository;
  final math.Random _random;
  final VariantPicker _picker;
  final UtcOffsetAt _utcOffsetAt;

  /// [extraNew] — сверх дневного лимита (по умолчанию 0).
  Future<SessionQueue> build({
    required DateTime now,
    SessionSettings settings = const SessionSettings(),
    int extraNew = 0,
  }) async {
    assert(extraNew >= 0, 'extraNew не может быть отрицательным');
    final utcNow = now.toUtc();
    final deckIds = settings.deckIds;

    final due = _shuffleTies(
      await _repository.dueStates(now: utcNow, deckIds: deckIds),
    ).take(settings.sessionSize).toList();

    final day = LocalDay.containing(utcNow, _utcOffsetAt);
    final shownToday = await _repository.countNewItemsFirstShown(
      from: day.start,
      to: day.end,
    );
    final newLeftToday = math.max(0, settings.newPerDay - shownToday);
    final newToTake = math.min(
      newLeftToday + extraNew,
      settings.sessionSize - due.length,
    );
    // На одно больше, чем берём: так видно, остались ли ещё новые.
    final newItems = await _repository.newItems(
      deckIds: deckIds,
      limit: newToTake + 1,
    );

    final newToShow = newItems.take(newToTake).toList();
    final ids = {
      for (final s in due) s.itemId,
      for (final i in newToShow) i.id,
    };
    final content = await _repository.contentFor(ids);
    final lastShownAt = await _repository.lastShownAt(ids);

    // `null`: у знания нет видимых вопросов (гонка с жалобой/обновлением
    // колоды), оно пропускается.
    SessionItem? pick(ItemState? state, String itemId) {
      final c = content[itemId];
      if (c == null) return null;
      final question = _picker.pick(
        questions: c.questions,
        state: state,
        hiddenQuestionIds: const {},
        lastShownAt: lastShownAt,
      );
      if (question == null) return null;
      return SessionItem(
        item: c.item,
        deckVersion: c.deckVersion,
        question: question,
        state:
            state ??
            Scheduler.initialState(
              itemId: c.item.id,
              deckId: c.item.deckId,
              now: utcNow,
            ),
      );
    }

    final items = <SessionItem>[];
    var dueCount = 0;
    for (final state in due) {
      final item = pick(state, state.itemId);
      if (item != null) {
        items.add(item);
        dueCount++;
      }
    }
    for (final newItem in newToShow) {
      final item = pick(null, newItem.id);
      if (item != null) items.add(item);
    }

    return SessionQueue(
      items: items,
      dueCount: dueCount,
      newCount: items.length - dueCount,
      nextDue: await _repository.nextDue(after: utcNow, deckIds: deckIds),
      moreNewAvailable: newItems.length > newToTake,
    );
  }

  /// Состояния уже отсортированы по `due`; в группах с одинаковым `due`
  /// порядок случайный.
  List<ItemState> _shuffleTies(List<ItemState> sorted) {
    final result = <ItemState>[];
    var i = 0;
    while (i < sorted.length) {
      var j = i + 1;
      while (j < sorted.length && sorted[j].due == sorted[i].due) {
        j++;
      }
      final group = sorted.sublist(i, j);
      if (group.length > 1) group.shuffle(_random);
      result.addAll(group);
      i = j;
    }
    return result;
  }
}
