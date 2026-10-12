import '../../../features/auth/domain/auth_user.dart';
import 'sync_service.dart';
import 'sync_store.dart';

/// Реакция на смену пользователя (ADR-30). Помнит, чьи данные лежат на
/// устройстве ([SyncStore.lastOwner]), и при входе нового пользователя
/// переносит на него локальные данные прежнего, только если это разрешает
/// [shouldAdoptLocalData] (потерянный анонимный аккаунт). Иначе данные
/// прежнего пользователя остаются под его `user_id`: не показываются, не
/// отправляются под чужой сессией, ждут его возвращения.
class AccountSwitchHandler {
  AccountSwitchHandler({required this._store, required this._sync});

  final SyncStore _store;
  final SyncService _sync;

  /// Вызывать на каждый вход (в том числе восстановленную при старте
  /// сессию). Повторный вызов с тем же пользователем ничего не делает.
  Future<void> onSignedIn(AuthUser user) async {
    final previous = await _store.lastOwner();
    if (previous == user) return;
    if (previous != null &&
        shouldAdoptLocalData(previous: previous, current: user)) {
      await _sync.adoptLocalData(from: previous.id, to: user.id);
    }
    await _store.saveOwner(user);
  }
}
