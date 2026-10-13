import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../data/duel_providers.dart';
import '../domain/duel_status.dart';
import 'duel_detail_notifier.dart';

/// Вопросы дуэли [duelId], на которые я уже ответил: на сервере и в очереди
/// отправки. Нужен экрану дуэли, чтобы сразу после последнего ответа показать
/// «ждём соперника», не дожидаясь, пока ответы дойдут до сервера. Сбой сети
/// или хранилища не ошибка: тогда берётся то, что удалось прочитать.
final duelProgressProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, duelId) async {
      final duel = await ref.watch(duelDetailProvider(duelId).future);
      if (duel == null) return {};
      if (duel.myDoneAt != null) return {...duel.questionIds};
      if (duel.status != DuelStatus.open && duel.status != DuelStatus.active) {
        return {};
      }
      final answered = <String>{};
      try {
        answered.addAll(
          await ref.read(duelAnswerQueueProvider).pendingQuestionIds(duelId),
        );
      } on AppError {
        // Очередь не прочиталась: берём только серверные ответы.
      }
      try {
        final server = await ref.read(duelRepositoryProvider).answers(duelId);
        answered.addAll([for (final a in server.mine) a.questionId]);
      } on AppError {
        // Нет сети: берём только очередь.
      }
      return answered;
    });
