import '../../../features/auth/domain/account_intent.dart';
import '../../../features/auth/domain/auth_user.dart';
import 'sync_service.dart';
import 'sync_store.dart';

/// Реакция на смену пользователя (ADR-30, ADR-34). Помнит, чьи данные лежат
/// на устройстве ([SyncStore.lastOwner]), и при входе нового пользователя
/// переносит на него локальные данные прежнего только в двух случаях:
///
/// - прежний и новый анонимные ([shouldAdoptLocalData]): потерянный
///   анонимный аккаунт того же человека;
/// - прежний анонимный, новый Google, и пользователь явно подтвердил
///   объединение ([shouldAdoptConfirmedMerge], намерение `merge`).
///
/// Иначе данные прежнего пользователя остаются под его `user_id`: не
/// показываются, не отправляются под чужой сессией, ждут его возвращения.
///
/// Привязка Google (тот же `id`, `isAnonymous` стал `false`) данных не
/// переносит: строки и так принадлежат этому `id`.
class AccountSwitchHandler {
  AccountSwitchHandler({
    required this._store,
    required this._sync,
    required this._intents,
    required this._clock,
  });

  final SyncStore _store;
  final SyncService _sync;
  final AccountIntentStore _intents;
  final DateTime Function() _clock;

  /// Вызывать на каждый вход (в том числе восстановленную при старте
  /// сессию). Повторный вызов с тем же пользователем ничего не делает: в том
  /// числе не трогает намерение, которое ещё ждёт возврата из браузера.
  Future<void> onSignedIn(AuthUser user) async {
    final previous = await _store.lastOwner();
    if (previous == user) return;
    if (previous != null && previous.id == user.id) {
      // Привязка завершена: тот же пользователь, но уже не анонимный.
      await _intents.clearIntent();
    } else if (previous != null) {
      final intent = await _intents.readIntent();
      if (shouldAdoptLocalData(previous: previous, current: user) ||
          shouldAdoptConfirmedMerge(
            previous: previous,
            current: user,
            intent: intent,
            now: _clock(),
          )) {
        await _sync.adoptLocalData(from: previous.id, to: user.id);
      }
      // Вход другого пользователя закрывает любое незавершённое намерение:
      // оно было про прежнего, и использовать его повторно нельзя.
      await _intents.clearIntent();
    }
    await _store.saveOwner(user);
  }
}
