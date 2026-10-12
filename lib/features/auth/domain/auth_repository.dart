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
}
