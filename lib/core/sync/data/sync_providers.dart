import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/data/auth_providers.dart';
import '../../../features/auth/domain/auth_user.dart';
import '../../db/database_providers.dart';
import '../../supabase/supabase_config.dart';
import '../../supabase/supabase_init.dart';
import '../../utils/clock.dart';
import '../domain/account_switch_handler.dart';
import '../domain/outbox_handler.dart';
import '../domain/sync_coordinator.dart';
import '../domain/sync_remote.dart';
import '../domain/sync_service.dart';
import '../domain/sync_store.dart';
import 'supabase_sync_remote.dart';

final syncRemoteProvider = Provider<SyncRemote>(
  (ref) => SupabaseSyncRemote(ref.watch(supabaseClientProvider)),
);

final syncStoreProvider = Provider<SyncStore>(
  (ref) => ref.watch(appDatabaseProvider).syncDao,
);

/// Реестр обработчиков outbox (шаг 3 §7.3). T20 добавит `report`, T23 —
/// `duelAnswer`.
final outboxHandlersProvider = Provider<OutboxHandlers>((ref) => const {});

final syncServiceProvider = Provider<SyncService>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return SyncService(
    remote: ref.watch(syncRemoteProvider),
    store: ref.watch(syncStoreProvider),
    currentUserId: () => auth.currentUser?.id,
    clock: ref.watch(clockProvider),
    outboxHandlers: ref.watch(outboxHandlersProvider),
  );
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final service = ref.watch(syncServiceProvider);
  final coordinator = SyncCoordinator(
    sync: service.sync,
    onReport: (report) {
      if (!report.isSuccess) debugPrint('Синхронизация: $report');
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// «Синхронизировать сейчас» для фич (конец сессии). Без бэкенда
/// (`SUPABASE_URL` не задан, в том числе в тестах) — ничего не делает.
final syncRequestProvider = Provider<void Function()>((ref) {
  if (!SupabaseConfig.isConfigured) return () {};
  final coordinator = ref.watch(syncCoordinatorProvider);
  return () => unawaited(coordinator.requestSync());
});

/// Запуск синхронизации из `main` (только с настроенным Supabase): первый
/// прогон и расписание, прогон на каждый вход (после переноса данных
/// потерянного анонимного аккаунта, ADR-28) и при возврате в приложение.
final syncBootstrapProvider = Provider<void>((ref) {
  final coordinator = ref.watch(syncCoordinatorProvider);
  final switcher = AccountSwitchHandler(
    store: ref.watch(syncStoreProvider),
    sync: ref.watch(syncServiceProvider),
  );
  // События входа обрабатываются строго по порядку: gotrue повторяет
  // подписчику прошлые события, и перенос данных не должен обогнать
  // предыдущий.
  var chain = Future<void>.value();
  Future<void> onUser(AuthUser user) async {
    try {
      await switcher.onSignedIn(user);
    } on Object catch (e) {
      debugPrint('Смена пользователя: $e');
    }
    await coordinator.requestSync();
  }

  final sub = ref.watch(authRepositoryProvider).userChanges().listen((user) {
    if (user != null) chain = chain.then((_) => onUser(user));
  });
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(coordinator.requestSync()),
  );
  coordinator.start();
  ref.onDispose(() {
    unawaited(sub.cancel());
    lifecycle.dispose();
  });
});
