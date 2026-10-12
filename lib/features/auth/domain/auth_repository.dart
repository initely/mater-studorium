import 'account_failure.dart';
import 'auth_user.dart';

/// Вход пользователя. Реализация в `data/`; `domain/` ничего не знает о Supabase.
abstract interface class AuthRepository {
  /// Гарантирует, что есть сессия: если её нет, выполняет анонимный вход.
  /// Одна попытка, без повторов.
  ///
  /// Бросает типизированные ошибки из `core/errors/`:
  /// `NetworkError` (нет сети или сервер недоступен, можно повторить),
  /// `AuthError` (сервер отказал), `UnexpectedError`.
  Future<void> ensureSignedIn();

  /// Текущий пользователь или `null`, если сессии нет.
  AuthUser? get currentUser;

  /// Смены пользователя: вход, выход (`null`), смена аккаунта. Подряд
  /// одинаковые значения не повторяются (обновление токена не событие).
  Stream<AuthUser?> userChanges();

  /// Открывает браузер, чтобы привязать Google к текущему аккаунту
  /// (`linkIdentity`, ADR-34). Возвращается, когда браузер открыт: итог
  /// приходит позже. Успех: тот же `id`, `isAnonymous == false` в
  /// [userChanges]. Неудача после возврата: [oauthFailures].
  ///
  /// Бросает `ProviderUnavailableError` (Google не настроен на сервере),
  /// `NetworkError`, `AuthError`, `UnexpectedError`.
  Future<void> linkGoogle();

  /// Открывает браузер, чтобы войти в существующий аккаунт Google. Итог:
  /// [userChanges] с другим `id`. Те же ошибки, что у [linkGoogle].
  Future<void> signInWithGoogle();

  /// Ошибки возврата из браузера (на web приходят после перезагрузки
  /// страницы, поэтому поток повторяет прошлые). Читать только вместе с
  /// `AccountIntent`: без него событие ничего не значит.
  Stream<AccountFailure> oauthFailures();
}
