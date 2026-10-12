import 'dart:async';

import '../../../core/errors/app_error.dart';
import 'account_event.dart';
import 'account_failure.dart';
import 'account_intent.dart';
import 'auth_repository.dart';

/// Привязка Google и вход в существующий аккаунт (T21, ADR-34). Чистый Dart.
///
/// Порядок на примере конфликта:
/// 1. [startLink]: пишется намерение `link`, открывается браузер;
/// 2. Google/GoTrue отвечает `identity_already_exists`: [events] выдаёт
///    [AccountEvent.conflict] (только пока намерение `link` свежее);
/// 3. пользователь подтверждает: [confirmMerge] пишет намерение `merge` и
///    открывает вход в существующий аккаунт; отказ: [decline];
/// 4. после входа `AccountSwitchHandler` видит намерение `merge` и только
///    тогда переносит локальный прогресс на новый аккаунт.
///
/// Данные не переносит и пользователя не меняет: это делают GoTrue и
/// `AccountSwitchHandler`.
class AccountLinkService {
  AccountLinkService({
    required this._auth,
    required this._intents,
    required this._clock,
  });

  final AuthRepository _auth;
  final AccountIntentStore _intents;
  final DateTime Function() _clock;

  /// Привязать Google к текущему анонимному аккаунту. `null`: браузер открыт,
  /// итог придёт позже; иначе причина, почему открыть не удалось.
  Future<AccountEvent?> startLink() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return AccountEvent.failed;
    return _launch(AccountIntentKind.link, user.id, _auth.linkGoogle);
  }

  /// Пользователь подтвердил вход в существующий аккаунт с объединением
  /// прогресса. Работает только из анонимного аккаунта, который сейчас
  /// открыт: намерение привязывается к его `id`.
  Future<AccountEvent?> confirmMerge() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return AccountEvent.failed;
    return _launch(AccountIntentKind.merge, user.id, _auth.signInWithGoogle);
  }

  /// Отказ от входа в существующий аккаунт: намерение сбрасывается, данные и
  /// аккаунт остаются как были.
  Future<void> decline() => _intents.clearIntent();

  Future<AccountEvent?> _launch(
    AccountIntentKind kind,
    String userId,
    Future<void> Function() open,
  ) async {
    await _intents.writeIntent(
      AccountIntent(kind: kind, fromUserId: userId, createdAt: _clock()),
    );
    try {
      await open();
      return null;
    } on ProviderUnavailableError {
      await _intents.clearIntent();
      return AccountEvent.unavailable;
    } on NetworkError {
      await _intents.clearIntent();
      return AccountEvent.network;
    } on AppError {
      await _intents.clearIntent();
      return AccountEvent.failed;
    }
  }

  /// Итоги, пришедшие после возврата из браузера. Событие считается
  /// «нашим», только если на устройстве есть свежее намерение того же
  /// анонимного пользователя; иначе (старое повторённое событие, чужой
  /// переход по ссылке) оно игнорируется.
  Stream<AccountEvent> events() => _auth
      .oauthFailures()
      .asyncMap(_eventFor)
      .where((event) => event != null)
      .map((event) => event!);

  Future<AccountEvent?> _eventFor(AccountFailure failure) async {
    final intent = await _intents.readIntent();
    final user = _auth.currentUser;
    if (intent == null ||
        intent.kind == AccountIntentKind.relogin ||
        !intent.isFresh(_clock()) ||
        user == null ||
        !user.isAnonymous ||
        user.id != intent.fromUserId) {
      return null;
    }
    switch (failure.kind) {
      case AccountFailureKind.identityAlreadyExists:
        // Конфликт возможен только при привязке; намерение остаётся `link`
        // до решения пользователя.
        if (intent.kind != AccountIntentKind.link) return null;
        return AccountEvent.conflict;
      case AccountFailureKind.cancelled:
        await _intents.clearIntent();
        return AccountEvent.cancelled;
      case AccountFailureKind.other:
        await _intents.clearIntent();
        return AccountEvent.failed;
    }
  }
}
