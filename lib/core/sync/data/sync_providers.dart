import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/data/account_providers.dart';
import '../../../features/auth/data/auth_providers.dart';
import '../../../features/auth/domain/auth_user.dart';
import '../../db/database_providers.dart';
import '../../supabase/supabase_config.dart';
import '../../supabase/supabase_init.dart';
import '../../utils/clock.dart';
import '../domain/account_switch_handler.dart';
import '../domain/outbox_handler.dart';
import '../domain/report_outbox_handler.dart';
import '../domain/sync_coordinator.dart';
import '../domain/sync_remote.dart';
import '../domain/sync_service.dart';
import '../domain/sync_store.dart';
import '../outbox_entry.dart';
import 'supabase_sync_remote.dart';

final syncRemoteProvider = Provider<SyncRemote>(
  (ref) => SupabaseSyncRemote(ref.watch(supabaseClientProvider)),
);

final syncStoreProvider = Provider<SyncStore>(
  (ref) => ref.watch(appDatabaseProvider).syncDao,
);

/// Реестр обработчиков outbox (шаг 3 §7.3): `report` (T20); `duelAnswer`
/// добавит T23.
final outboxHandlersProvider = Provider<OutboxHandlers>(
  (ref) => {
    OutboxKind.report: reportOutboxHandler(ref.watch(syncRemoteProvider)),
  },
);

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

/// Обработчик смены пользователя (ADR-30, ADR-34).
final accountSwitchHandlerProvider = Provider<AccountSwitchHandler>(
  (ref) => AccountSwitchHandler(
    store: ref.watch(syncStoreProvider),
    sync: ref.watch(syncServiceProvider),
    intents: ref.watch(accountIntentStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Последний значимый итог входа (перенесён прогресс, не подтверждён, не
/// удался): блок «Аккаунт» говорит по нему правду о прогрессе.
class AccountSwitchResultNotifier extends Notifier<AccountSwitchResult?> {
  @override
  AccountSwitchResult? build() => null;

  void publish(AccountSwitchResult result) => state = result;
}

final accountSwitchResultProvider =
    NotifierProvider<AccountSwitchResultNotifier, AccountSwitchResult?>(
      AccountSwitchResultNotifier.new,
    );

/// Запуск синхронизации из `main` (только с настроенным Supabase): первый
/// прогон и расписание, прогон на каждый вход (после переноса данных
/// потерянного анонимного аккаунта, ADR-30) и при возврате в приложение.
final syncBootstrapProvider = Provider<void>((ref) {
  final coordinator = ref.watch(syncCoordinatorProvider);
  final switcher = ref.watch(accountSwitchHandlerProvider);
  // События входа обрабатываются строго по порядку: gotrue повторяет
  // подписчику прошлые события, и перенос данных не должен обогнать
  // предыдущий.
  var chain = Future<void>.value();
  Future<void> onUser(AuthUser user) async {
    try {
      final result = await switcher.onSignedIn(user);
      if (result.outcome != AccountSwitchOutcome.none) {
        ref.read(accountSwitchResultProvider.notifier).publish(result);
      }
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
