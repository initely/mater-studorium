/// Типизированные ошибки, которые репозитории отдают наверх вместо сырых
/// исключений Supabase и drift (CLAUDE.md, «Соглашения»).
sealed class AppError implements Exception {
  const AppError(this.message, {this.cause});

  /// Техническое описание для логов, не для показа пользователю.
  final String message;

  /// Исходное исключение, если оно есть.
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// Нет сети или сервер временно недоступен: операцию можно повторить позже.
final class NetworkError extends AppError {
  const NetworkError(super.message, {super.cause});
}

/// Сервер отклонил запрос авторизации (например, anonymous sign-ins выключены).
/// Повтор сам по себе не поможет.
final class AuthError extends AppError {
  const AuthError(super.message, {super.cause});
}

/// Всё остальное, чего мы не ожидали.
final class UnexpectedError extends AppError {
  const UnexpectedError(super.message, {super.cause});
}
