import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../../core/sync/data/sync_providers.dart';
import '../../../core/utils/clock.dart';
import '../../session/data/session_providers.dart';
import '../domain/duel_answer_queue.dart';
import '../domain/duel_content.dart';
import '../domain/duel_question_source.dart';
import '../domain/duel_repository.dart';
import '../domain/duel_seen_store.dart';
import 'drift_duel_answer_queue.dart';
import 'drift_duel_content_source.dart';
import 'drift_duel_question_source.dart';
import 'drift_duel_seen_store.dart';
import 'supabase_duel_repository.dart';
import 'unavailable_duel_repository.dart';

/// Дуэли на сервере. В тестах подменяется.
final duelRepositoryProvider = Provider<DuelRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? const UnavailableDuelRepository()
      : SupabaseDuelRepository(client);
});

/// Вопросы скачанных колод для новой дуэли. В тестах подменяется.
final duelQuestionSourceProvider = Provider<DuelQuestionSource>(
  (ref) => DriftDuelQuestionSource(ref.watch(decksDaoProvider)),
);

/// Вопросы дуэли из скачанной колоды для игры и разбора (T23). В тестах
/// подменяется.
final duelContentSourceProvider = Provider<DuelContentSource>(
  (ref) => DriftDuelContentSource(ref.watch(decksDaoProvider)),
);

/// Очередь отправки ответов дуэли (outbox, `kind = duel_answer`). После
/// постановки в очередь просит `SyncService` отправить её. В тестах
/// подменяется.
final duelAnswerQueueProvider = Provider<DuelAnswerQueue>(
  (ref) => DriftDuelAnswerQueue(
    db: ref.watch(appDatabaseProvider),
    userId: ref.watch(sessionUserIdProvider),
    clock: ref.watch(clockProvider),
    onQueued: ref.watch(syncRequestProvider),
  ),
);

/// Какие результаты дуэлей уже открыты (карточки на главном). В тестах
/// подменяется.
final duelSeenStoreProvider = Provider<DuelSeenStore>(
  (ref) => DriftDuelSeenStore(ref.watch(settingsDaoProvider)),
);

/// Как часто экран дуэли сам перечитывает состояние, пока ждёт соперника
/// (ТЗ §6.4: realtime в MVP не нужен). `null` — не опрашивать (тесты).
final duelPollIntervalProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 30),
);
