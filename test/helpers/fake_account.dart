import 'dart:async';

import 'package:mater_studorium/features/auth/domain/account_failure.dart';
import 'package:mater_studorium/features/auth/domain/account_intent.dart';
import 'package:mater_studorium/features/auth/domain/auth_repository.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';

/// Хранилище намерения в памяти.
class MemoryIntentStore implements AccountIntentStore {
  MemoryIntentStore([this.intent]);

  AccountIntent? intent;

  @override
  Future<AccountIntent?> readIntent() async => intent;

  @override
  Future<void> writeIntent(AccountIntent value) async => intent = value;

  @override
  Future<void> clearIntent() async => intent = null;
}

/// Репозиторий входа без сети: пользователь, итоги возврата из браузера и
/// ошибки открытия браузера задаются из теста.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([AuthUser? user]) : _user = user;

  AuthUser? _user;
  final _users = StreamController<AuthUser?>.broadcast();
  final _failures = StreamController<AccountFailure>.broadcast();

  /// Что бросит следующее открытие браузера (`null` — откроется).
  Object? launchError;

  Completer<void>? _gate;

  /// Следующее открытие браузера ждёт `complete()` (кнопка «открываем»).
  Completer<void> hold() => _gate = Completer<void>();

  /// Сколько раз открывали браузер для привязки и для входа.
  var linkCalls = 0;
  var signInCalls = 0;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> userChanges() => _users.stream;

  @override
  Future<void> ensureSignedIn() async {}

  @override
  Future<void> linkGoogle() async {
    linkCalls++;
    await _gate?.future;
    final error = launchError;
    if (error != null) throw error;
  }

  @override
  Future<void> signInWithGoogle() async {
    signInCalls++;
    final error = launchError;
    if (error != null) throw error;
  }

  @override
  Stream<AccountFailure> oauthFailures() => _failures.stream;

  /// Сервер сообщил о смене пользователя (вход, привязка).
  void emitUser(AuthUser? user) {
    _user = user;
    _users.add(user);
  }

  /// Ошибка возврата из браузера.
  void emitFailure(AccountFailureKind kind) =>
      _failures.add(AccountFailure(kind));

  Future<void> dispose() async {
    await _users.close();
    await _failures.close();
  }
}
