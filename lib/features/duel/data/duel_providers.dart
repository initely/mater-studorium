import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../../../core/supabase/supabase_init.dart';
import '../domain/duel_question_source.dart';
import '../domain/duel_repository.dart';
import 'drift_duel_question_source.dart';
import 'supabase_duel_repository.dart';

/// Дуэли на сервере. В тестах подменяется.
final duelRepositoryProvider = Provider<DuelRepository>(
  (ref) => SupabaseDuelRepository(ref.watch(supabaseClientProvider)),
);

/// Вопросы скачанных колод для новой дуэли. В тестах подменяется.
final duelQuestionSourceProvider = Provider<DuelQuestionSource>(
  (ref) => DriftDuelQuestionSource(ref.watch(decksDaoProvider)),
);
