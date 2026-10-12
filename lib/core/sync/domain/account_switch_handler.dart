import '../../../features/auth/domain/account_intent.dart';
import '../../../features/auth/domain/auth_user.dart';
import 'sync_service.dart';
import 'sync_store.dart';

/// Чем закончилась обработка входа.
enum AccountSwitchOutcome {
  /// Переносить было нечего или не нужно (первый вход, тот же пользователь,
  /// привязка с тем же `id`, чужой не анонимный прежний).
  none,

  /// Локальный прогресс прежнего пользователя перенесён на нового.
  adopted,

  /// Анонимный аккаунт сменился на Google-аккаунт, но перенос не разрешён:
  /// подтверждение («Войти и объединить») устарело (больше 15 минут), его
  /// не было или оно про другого пользователя. Прогресс остался на
  /// устройстве под прежним анонимным `user_id`.
  notConfirmed,

  /// Перенос разрешён, но не удался (ошибка локальной БД). Ничего не
  /// потеряно: транзакция откатена, данные остались под прежним `user_id`.
  failed,
}

/// Итог обработки входа и для кого он: нужен экрану, чтобы честно сказать,
/// что стало с прогрессом, и предложить повторить.
class AccountSwitchResult {
  const AccountSwitchResult(this.outcome, {this.fromUserId, this.user});

  const AccountSwitchResult.none() : this(AccountSwitchOutcome.none);

  final AccountSwitchOutcome outcome;

  /// Прежний анонимный пользователь, чей прогресс затронут (для
  /// `notConfirmed` и `failed`).
  final String? fromUserId;

  /// Пользователь, который вошёл.
  final AuthUser? user;
}

/// Реакция на смену пользователя (ADR-30, ADR-34). Помнит, чьи данные лежат
/// на устройстве ([SyncStore.lastOwner]), и при входе нового пользователя
/// переносит на него локальные данные прежнего только в двух случаях:
///
/// - прежний и новый анонимные и приложение само повторно входило анонимно
///   после потери сессии ([shouldAdoptAfterRelogin], запись `relogin`);
/// - прежний анонимный, новый Google, и пользователь явно подтвердил
///   объединение ([shouldAdoptConfirmedMerge], запись `merge`).
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
  /// сессию). Повторный вызов с тем же пользователем ничего не переносит и
  /// не трогает ожидающие `link` и `merge`.
  Future<AccountSwitchResult> onSignedIn(AuthUser user) async {
    final previous = await _store.lastOwner();
    if (previous == user) {
      await _clearRelogin();
      return const AccountSwitchResult.none();
    }
    if (previous == null) {
      await _store.saveOwner(user);
      return const AccountSwitchResult.none();
    }
    if (previous.id == user.id) {
      // Привязка завершена: тот же пользователь, но уже не анонимный.
      await _intents.clearIntent();
      await _store.saveOwner(user);
      return const AccountSwitchResult.none();
    }
    final intent = await _intents.readIntent();
    final adopt =
        shouldAdoptAfterRelogin(
          previous: previous,
          current: user,
          intent: intent,
        ) ||
        shouldAdoptConfirmedMerge(
          previous: previous,
          current: user,
          intent: intent,
          now: _clock(),
        );
    if (adopt) {
      try {
        await _sync.adoptLocalData(from: previous.id, to: user.id);
      } on Object {
        // Транзакция откатилась. Владельца и намерение не трогаем: следующий
        // вход (или повтор по кнопке) попробует снова.
        return AccountSwitchResult(
          AccountSwitchOutcome.failed,
          fromUserId: previous.id,
          user: user,
        );
      }
    }
    // Вход другого пользователя закрывает любое незавершённое намерение:
    // оно было про прежнего, и использовать его повторно нельзя.
    await _intents.clearIntent();
    await _store.saveOwner(user);
    if (adopt) {
      return AccountSwitchResult(
        AccountSwitchOutcome.adopted,
        fromUserId: previous.id,
        user: user,
      );
    }
    final toGoogle = previous.isAnonymous && !user.isAnonymous;
    return toGoogle
        ? AccountSwitchResult(
            AccountSwitchOutcome.notConfirmed,
            fromUserId: previous.id,
            user: user,
          )
        : const AccountSwitchResult.none();
  }

  /// Повтор переноса по явной кнопке пользователя, который уже вошёл в
  /// Google-аккаунт [user]: прогресс [fromUserId] остался на устройстве
  /// (подтверждение устарело или перенос не удался). Нажатие и есть
  /// подтверждение.
  Future<AccountSwitchResult> adoptConfirmed({
    required String fromUserId,
    required AuthUser user,
  }) async {
    if (user.isAnonymous || user.id == fromUserId) {
      return const AccountSwitchResult.none();
    }
    try {
      await _sync.adoptLocalData(from: fromUserId, to: user.id);
    } on Object {
      return AccountSwitchResult(
        AccountSwitchOutcome.failed,
        fromUserId: fromUserId,
        user: user,
      );
    }
    await _intents.clearIntent();
    await _store.saveOwner(user);
    return AccountSwitchResult(
      AccountSwitchOutcome.adopted,
      fromUserId: fromUserId,
      user: user,
    );
  }

  /// Тот же пользователь вернулся: запись `relogin` отработала или устарела.
  Future<void> _clearRelogin() async {
    final intent = await _intents.readIntent();
    if (intent?.kind == AccountIntentKind.relogin) await _intents.clearIntent();
  }
}
