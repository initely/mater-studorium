import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/clock.dart';
import '../data/duel_providers.dart';
import '../domain/duel.dart';
import '../domain/duel_stage.dart';
import 'my_duels_notifier.dart';

/// Сколько карточек дуэлей показывает главный экран.
const kDuelCardsLimit = 4;

/// Результат старше этого срока карточкой на главном не напоминается.
const kDuelResultCardAge = Duration(days: 3);

/// Дуэли, о которых главный экран напоминает карточкой (ТЗ §8.4): «твой ход»,
/// «ждём» (я ответил на все) и «результат» (оба закончили, результат ещё не
/// открывался на этом устройстве, не старше [kDuelResultCardAge]). Порядок:
/// твой ход, результат, ждём; внутри — как в списке (новые первыми). Истёкшие
/// не показываются. Список читается с сервера (`my_duels`); ошибка сети — пустой
/// список: карточки не обязательная часть главного.
final duelCardsProvider = FutureProvider.autoDispose<List<Duel>>((ref) async {
  final duels = await ref.watch(myDuelsProvider.future);
  var seen = <String>{};
  try {
    seen = await ref.read(duelSeenStoreProvider).seenResults();
  } on AppError {
    // Не прочиталось: покажем результаты как непросмотренные.
  }
  final now = ref.read(clockProvider)();
  int rank(DuelStage s) => switch (s) {
    DuelStage.yourTurn => 0,
    DuelStage.result => 1,
    DuelStage.waiting => 2,
    DuelStage.expired => 3,
  };
  final cards = <(int, int, Duel)>[];
  for (var i = 0; i < duels.length; i++) {
    final d = duels[i];
    final stage = duelStageFor(d, d.statusAt(now));
    if (stage == DuelStage.expired) continue;
    if (stage == DuelStage.result) {
      if (seen.contains(d.id)) continue;
      final doneAt = [d.myDoneAt, d.otherDoneAt].nonNulls.fold<DateTime?>(
        null,
        (a, b) => a == null || b.isAfter(a) ? b : a,
      );
      if (doneAt != null && now.difference(doneAt) > kDuelResultCardAge) {
        continue;
      }
    }
    cards.add((rank(stage), i, d));
  }
  cards.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [for (final c in cards.take(kDuelCardsLimit)) c.$3];
});
