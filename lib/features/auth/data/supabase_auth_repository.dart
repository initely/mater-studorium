import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_config.dart';
import '../domain/account_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Открывает адрес входа во внешнем браузере. Подменяется в тестах.
typedef AuthUrlLauncher = Future<bool> Function(Uri url);

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._auth, {
    String Function()? redirectTo,
    AuthUrlLauncher? launcher,
    Uri? supabaseUrl,
  }) : _supabaseUrl = supabaseUrl ?? Uri.tryParse(SupabaseConfig.url),
       _redirectTo = redirectTo ?? (() => SupabaseConfig.oauthRedirectUrl),
       _launch = launcher ?? _launchInBrowser;

  final GoTrueClient _auth;
  final String Function() _redirectTo;
  final AuthUrlLauncher _launch;
  final Uri? _supabaseUrl;

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  /// gotrue отдаёт сетевые сбои обновления токена ошибками потока; это не
  /// смена пользователя, поэтому они отбрасываются (сессия остаётся, токен
  /// обновится при появлении сети). Поток gotrue повторяет новым подписчикам
  /// прошлые события по порядку, последнее — текущее состояние.
  @override
  Stream<AuthUser?> userChanges() => _auth.onAuthStateChange
      .map((s) => _map(s.session?.user))
      .handleError((Object _) {})
      .distinct();

  static AuthUser? _map(User? user) => user == null
      ? null
      : AuthUser(id: user.id, isAnonymous: user.isAnonymous, email: user.email);

  /// Ошибки возврата из браузера: `getSessionFromUrl` бросает `AuthException`
  /// по `error_code` из адреса, supabase_flutter передаёт её в
  /// `notifyException`, и она приходит ошибкой того же потока
  /// `onAuthStateChange` (поток повторяет прошлые события, в том числе после
  /// перезагрузки страницы на web). Сетевые сбои обновления токена сюда не
  /// относятся и отбрасываются.
  @override
  Stream<AccountFailure> oauthFailures() {
    late final StreamController<AccountFailure> controller;
    StreamSubscription<Object?>? subscription;
    controller = StreamController<AccountFailure>(
      onListen: () {
        subscription = _auth.onAuthStateChange.listen(
          (_) {},
          onError: (Object error, StackTrace _) {
            final failure = accountFailureFor(error);
            if (failure != null) controller.add(failure);
          },
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> ensureSignedIn() async {
    // Сохранённая сессия (даже просроченная) считается входом: supabase_flutter
    // сам обновит токен, когда появится сеть.
    if (_auth.currentSession != null) return;
    try {
      await _auth.signInAnonymously();
    } on AuthRetryableFetchException catch (e) {
      // gotrue оборачивает сетевые сбои и ответы 5xx в этот тип.
      throw NetworkError(
        'Anonymous sign-in: сеть или сервер недоступны',
        cause: e,
      );
    } on AuthException catch (e) {
      // Лимит запросов (например, 30 анонимных входов в час с IP) временный:
      // повторяем с паузой, как при отсутствии сети.
      if (e.statusCode == '429' || e.code == 'over_request_rate_limit') {
        throw NetworkError('Anonymous sign-in: лимит запросов (429)', cause: e);
      }
      throw AuthError('Anonymous sign-in отклонён: ${e.message}', cause: e);
    } catch (e) {
      throw UnexpectedError('Anonymous sign-in: неожиданная ошибка', cause: e);
    }
  }

  @override
  Future<void> linkGoogle() => _openBrowser(
    'Привязка Google',
    () async => (await _auth.getLinkIdentityUrl(
      OAuthProvider.google,
      redirectTo: _redirectTo(),
    )).url,
  );

  @override
  Future<void> signInWithGoogle() => _openBrowser(
    'Вход через Google',
    () async => (await _auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: _redirectTo(),
    )).url,
  );

  Future<void> _openBrowser(
    String what,
    Future<String> Function() urlFor,
  ) async {
    try {
      final url = Uri.parse(await urlFor());
      // Адрес пришёл по сети: открываем только Google и свой сервер Supabase
      // (ревью T21, N4), чтобы подменённый ответ не увёл в чужое место.
      if (!isTrustedAuthUrl(url, supabaseUrl: _supabaseUrl)) {
        throw AuthError('$what: адрес входа не прошёл проверку (${url.host})');
      }
      final opened = await _launch(url);
      if (!opened) throw UnexpectedError('$what: браузер не открылся');
    } on AppError {
      rethrow;
    } on AuthException catch (e) {
      throw mapAuthLaunchError(what, e);
    } on FormatException catch (e) {
      throw UnexpectedError('$what: сервер вернул неверный адрес', cause: e);
    } catch (e) {
      throw UnexpectedError('$what: неожиданная ошибка', cause: e);
    }
  }
}

/// Адрес, который можно открыть в браузере для входа: Google по https или
/// собственный сервер Supabase ([supabaseUrl]; для локального стека допустим
/// http на loopback). Всё остальное (чужой хост, `javascript:`, `file:`,
/// http к постороннему хосту) отклоняется.
bool isTrustedAuthUrl(Uri url, {required Uri? supabaseUrl}) {
  if (url.userInfo.isNotEmpty) return false;
  final host = url.host.toLowerCase();
  if (url.scheme == 'https' && host == 'accounts.google.com') return true;
  final own = supabaseUrl;
  if (own == null || own.host.isEmpty || host != own.host.toLowerCase()) {
    return false;
  }
  if (url.port != own.port) return false;
  if (url.scheme == 'https') return true;
  return url.scheme == 'http' &&
      own.scheme == 'http' &&
      const {'127.0.0.1', 'localhost', '10.0.2.2', '::1'}.contains(host);
}

/// Ошибка GoTrue при получении адреса входа или привязки -> типизированная.
///
/// Google не настроен: `validation_failed` («provider is not enabled») или
/// `manual_linking_disabled`; оба ответа проверены на локальном стеке
/// (ADR-34).
AppError mapAuthLaunchError(String what, AuthException e) {
  if (e is AuthRetryableFetchException) {
    return NetworkError('$what: сеть или сервер недоступны', cause: e);
  }
  final code = e.code ?? e.statusCode;
  final message = e.message.toLowerCase();
  // `validation_failed` общий код GoTrue для любой ошибки проверки запроса,
  // поэтому по нему одному «не настроено» не считаем: нужен текст про
  // провайдера.
  if (code == 'manual_linking_disabled' ||
      message.contains('provider is not enabled') ||
      message.contains('unsupported provider')) {
    return ProviderUnavailableError('$what: Google не настроен', cause: e);
  }
  if (e.statusCode == '429' || code == 'over_request_rate_limit') {
    return NetworkError('$what: лимит запросов (429)', cause: e);
  }
  return AuthError('$what отклонена сервером: ${e.message}', cause: e);
}

/// Ошибка возврата из браузера -> причина для UI. `null`: к входу через
/// Google не относится (сеть, обновление токена).
///
/// gotrue собирает `AuthException(error_description, statusCode: error_code,
/// code: error)` из адреса возврата, поэтому код ошибки может лежать в обоих
/// полях.
AccountFailure? accountFailureFor(Object error) {
  if (error is! AuthException || error is AuthRetryableFetchException) {
    return null;
  }
  final fields = [
    error.statusCode,
    error.code,
    error.message,
  ].whereType<String>().map((s) => s.toLowerCase()).toList();
  bool has(String needle) => fields.any((f) => f.contains(needle));
  final detail = error.toString();
  if (has('identity_already_exists') ||
      has('identity is already linked') ||
      has('already linked to another user')) {
    return AccountFailure(
      AccountFailureKind.identityAlreadyExists,
      detail: detail,
    );
  }
  if (has('access_denied') || has('user_cancelled')) {
    return AccountFailure(AccountFailureKind.cancelled, detail: detail);
  }
  return AccountFailure(AccountFailureKind.other, detail: detail);
}

Future<bool> _launchInBrowser(Uri url) => launchUrl(
  url,
  // Google не разрешает вход во встроенных WebView: на Android нужен внешний
  // браузер. На web страница уходит на Google в этой же вкладке и
  // возвращается.
  mode: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? LaunchMode.externalApplication
      : LaunchMode.platformDefault,
  webOnlyWindowName: '_self',
);
