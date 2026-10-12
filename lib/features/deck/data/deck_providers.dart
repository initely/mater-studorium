import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../../session/data/session_providers.dart';
import '../domain/deck_details.dart';
import '../domain/deck_repository.dart';
import 'drift_deck_repository.dart';

final deckRepositoryProvider = Provider<DeckRepository>(
  (ref) => DriftDeckRepository(
    decks: ref.watch(decksDaoProvider),
    review: ref.watch(reviewDaoProvider),
    userId: ref.watch(sessionUserIdProvider),
  ),
);

/// Колода с прогрессом для экрана колоды; `null` — колоды нет на устройстве.
final deckDetailsProvider = StreamProvider.family<DeckDetails?, String>(
  (ref, deckId) => ref.watch(deckRepositoryProvider).watch(deckId),
);
