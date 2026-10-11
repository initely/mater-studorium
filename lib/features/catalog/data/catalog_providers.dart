import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../../core/utils/clock.dart';
import '../domain/catalog_repository.dart';
import 'deck_remote_source.dart';
import 'drift_catalog_repository.dart';
import 'supabase_deck_remote_source.dart';

/// Сервер каталога. Без `SUPABASE_URL` и ключа (запуск без бэкенда) каталог
/// ведёт себя как «нет сети». В тестах подменяется.
final deckRemoteSourceProvider = Provider<DeckRemoteSource>(
  (ref) => SupabaseConfig.isConfigured
      ? SupabaseDeckRemoteSource(ref.watch(supabaseClientProvider))
      : const UnavailableDeckRemoteSource(),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => DriftCatalogRepository(
    remote: ref.watch(deckRemoteSourceProvider),
    decks: ref.watch(decksDaoProvider),
    clock: ref.watch(clockProvider),
  ),
);
