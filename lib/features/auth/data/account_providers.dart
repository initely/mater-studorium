import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/utils/clock.dart';
import '../domain/account_intent.dart';
import '../domain/account_link_service.dart';
import 'auth_providers.dart';

/// Намерение «привязать Google» или «войти и объединить» хранится в
/// локальной БД (ADR-34).
final accountIntentStoreProvider = Provider<AccountIntentStore>(
  (ref) => ref.watch(appDatabaseProvider).syncDao,
);

final accountLinkServiceProvider = Provider<AccountLinkService>(
  (ref) => AccountLinkService(
    auth: ref.watch(authRepositoryProvider),
    intents: ref.watch(accountIntentStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Подключён ли бэкенд в этой сборке (`SUPABASE_URL` и ключ заданы). Без него
/// блок «Аккаунт» только сообщает об этом; в тестах подменяется.
final backendConfiguredProvider = Provider<bool>(
  (ref) => SupabaseConfig.isConfigured,
);
