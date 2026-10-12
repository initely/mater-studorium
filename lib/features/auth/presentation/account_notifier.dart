import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/data/sync_providers.dart';
import '../../../core/sync/domain/account_switch_handler.dart';
import '../data/account_providers.dart';
import '../data/auth_providers.dart';
import '../domain/account_event.dart';
import '../domain/auth_user.dart';

/// Что сейчас происходит с привязкой.
enum AccountPhase {
  idle,

  /// Открываем браузер (кнопки заблокированы).
  working,

  /// Google уже привязан к другому аккаунту: ждём решения пользователя.
  conflict,
}

/// Сообщение под блоком «Аккаунт»; пропадает при следующем действии.
enum AccountNotice {
  /// Google привязан, прогресс сохранён.
  linked,

  /// Вошли в существующий аккаунт Google, прогресс этого устройства перенесён
  /// (выводится только из итога `AccountSwitchHandler`).
  signedInExisting,

  /// Вошли в существующий аккаунт Google, но подтверждение устарело или его не
  /// было: прогресс не перенесён и остался на устройстве; можно повторить.
  mergeNotConfirmed,

  /// Перенос прогресса не удался, ничего не потеряно; можно повторить.
  mergeFailed,
  cancelled,

  /// Google не настроен в этой сборке или на сервере.
  unavailable,
  network,
  failed,
}

class AccountState {
  const AccountState({
    this.available = true,
    this.user,
    this.phase = AccountPhase.idle,
    this.notice,
    this.strandedFromUserId,
  });

  /// Бэкенд подключён. Без него блок только сообщает, что вход недоступен.
  final bool available;

  /// Текущий пользователь; `null` — входа ещё нет (идёт анонимный вход).
  final AuthUser? user;
  final AccountPhase phase;
  final AccountNotice? notice;

  /// Прежний анонимный пользователь, чей прогресс остался на устройстве и
  /// может быть перенесён кнопкой «Перенести прогресс» (после
  /// `mergeNotConfirmed` и `mergeFailed`).
  final String? strandedFromUserId;

  /// Требует внимания пользователя на экране настроек: диалог или сообщение
  /// о результате (после возврата из браузера приложение само открывает
  /// настройки).
  bool get needsAttention => phase == AccountPhase.conflict || notice != null;

  AccountState copyWith({
    AuthUser? user,
    AccountPhase? phase,
    AccountNotice? notice,
    bool clearNotice = false,
    String? strandedFromUserId,
    bool clearStranded = false,
  }) => AccountState(
    available: available,
    user: user ?? this.user,
    phase: phase ?? this.phase,
    notice: clearNotice ? null : (notice ?? this.notice),
    strandedFromUserId: clearStranded
        ? null
        : (strandedFromUserId ?? this.strandedFromUserId),
  );
}

/// Состояние привязки Google для настроек (T21, ADR-34). Логика и порядок
/// шагов в `AccountLinkService`; здесь только состояние для экрана.
///
/// Подписывается на пользователя и на итоги возврата из браузера сразу при
/// создании: на web возврат перезагружает страницу, и итог приходит до того,
/// как открыты настройки.
class AccountNotifier extends Notifier<AccountState> {
  AuthUser? _lastUser;

  @override
  AccountState build() {
    if (!ref.watch(backendConfiguredProvider)) {
      return const AccountState(available: false);
    }
    final auth = ref.read(authRepositoryProvider);
    final service = ref.read(accountLinkServiceProvider);
    // Поток пользователя повторяет подписчику прошлые события по порядку
    // (ReplaySubject в gotrue): на web после возврата из Google это сначала
    // восстановленный аноним, затем Google-аккаунт, и сообщение о привязке
    // выводится из этой пары, даже если обмен кода завершился до запуска.
    _lastUser = auth.currentUser;
    final users = auth.userChanges().listen(_onUser);
    final events = service.events().listen(_onEvent);
    ref.listen(
      accountSwitchResultProvider,
      (_, result) => _onSwitchResult(result),
    );
    // Итог мог прийти до создания уведомителя (возврат из Google на web):
    // состояние в `build` ещё не готово, применяем сразу после него.
    final early = ref.read(accountSwitchResultProvider);
    if (early != null) scheduleMicrotask(() => _onSwitchResult(early));
    ref.onDispose(() {
      unawaited(users.cancel());
      unawaited(events.cancel());
    });
    return AccountState(user: _lastUser);
  }

  void _onUser(AuthUser? user) {
    if (user == null || user == _lastUser) return;
    final previous = _lastUser;
    _lastUser = user;
    // Привязка с тем же id: прогресс остаётся под этим id, переносить нечего.
    // Вход в другой аккаунт: сообщение о прогрессе зависит от итога переноса
    // (`_onSwitchResult`), а не от самой смены пользователя.
    final linked =
        previous != null &&
        previous.isAnonymous &&
        !user.isAnonymous &&
        previous.id == user.id;
    state = state.copyWith(
      user: user,
      phase: AccountPhase.idle,
      notice: linked ? AccountNotice.linked : null,
      clearNotice: !linked,
    );
  }

  /// Итог обработки входа: честное сообщение о прогрессе (ревью T21, S1).
  void _onSwitchResult(AccountSwitchResult? result) {
    if (!ref.mounted ||
        result == null ||
        result.user == null ||
        result.user!.isAnonymous) {
      return;
    }
    switch (result.outcome) {
      case AccountSwitchOutcome.adopted:
        state = state.copyWith(
          notice: AccountNotice.signedInExisting,
          clearStranded: true,
        );
      case AccountSwitchOutcome.notConfirmed:
        state = state.copyWith(
          notice: AccountNotice.mergeNotConfirmed,
          strandedFromUserId: result.fromUserId,
        );
      case AccountSwitchOutcome.failed:
        state = state.copyWith(
          notice: AccountNotice.mergeFailed,
          strandedFromUserId: result.fromUserId,
        );
      case AccountSwitchOutcome.none:
        break;
    }
  }

  void _onEvent(AccountEvent event) {
    state = switch (event) {
      AccountEvent.conflict => state.copyWith(
        phase: AccountPhase.conflict,
        clearNotice: true,
      ),
      _ => state.copyWith(phase: AccountPhase.idle, notice: _noticeFor(event)),
    };
  }

  static AccountNotice _noticeFor(AccountEvent event) => switch (event) {
    AccountEvent.cancelled => AccountNotice.cancelled,
    AccountEvent.unavailable => AccountNotice.unavailable,
    AccountEvent.network => AccountNotice.network,
    AccountEvent.failed || AccountEvent.conflict => AccountNotice.failed,
  };

  /// «Привязать Google».
  Future<void> linkGoogle() =>
      _launch(ref.read(accountLinkServiceProvider).startLink);

  /// Подтверждение в диалоге конфликта: войти в существующий аккаунт и
  /// объединить прогресс этого устройства с ним.
  Future<void> confirmMerge() =>
      _launch(ref.read(accountLinkServiceProvider).confirmMerge);

  /// Отказ в диалоге конфликта.
  Future<void> declineMerge() async {
    await ref.read(accountLinkServiceProvider).decline();
    if (ref.mounted) state = state.copyWith(phase: AccountPhase.idle);
  }

  /// «Перенести прогресс»: пользователь уже в Google-аккаунте, а прогресс
  /// анонимного аккаунта остался на устройстве (подтверждение устарело или
  /// перенос не удался). Нажатие и есть подтверждение.
  Future<void> retryMerge() async {
    final from = state.strandedFromUserId;
    final user = state.user;
    if (from == null || user == null || user.isAnonymous) return;
    if (state.phase == AccountPhase.working) return;
    state = state.copyWith(phase: AccountPhase.working, clearNotice: true);
    final result = await ref
        .read(accountSwitchHandlerProvider)
        .adoptConfirmed(fromUserId: from, user: user);
    if (!ref.mounted) return;
    state = state.copyWith(phase: AccountPhase.idle);
    _onSwitchResult(result);
  }

  /// Скрыть сообщение о результате.
  void dismissNotice() => state = state.copyWith(clearNotice: true);

  Future<void> _launch(Future<AccountEvent?> Function() start) async {
    if (state.phase == AccountPhase.working || !state.available) return;
    state = state.copyWith(phase: AccountPhase.working, clearNotice: true);
    final event = await start();
    if (!ref.mounted) return;
    // Браузер открыт (event == null): итог придёт позже через события или
    // смену пользователя. Не блокируем кнопку навсегда: если человек закрыл
    // браузер, не вернувшись, он может нажать ещё раз.
    state = state.copyWith(
      phase: AccountPhase.idle,
      notice: event == null ? null : _noticeFor(event),
      clearNotice: event == null,
    );
  }
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(
  AccountNotifier.new,
);
