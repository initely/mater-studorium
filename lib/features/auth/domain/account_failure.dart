/// Почему вход через Google не завершился. Приходит после возврата из
/// браузера (на web страница при этом перезагружается), поэтому отдельным
/// потоком, а не результатом вызова.
enum AccountFailureKind {
  /// Этот Google-аккаунт уже привязан к другому пользователю приложения
  /// (`identity_already_exists`). Можно войти в него (ADR-34).
  identityAlreadyExists,

  /// Пользователь отказался на стороне Google (`access_denied`).
  cancelled,

  /// Любая другая ошибка возврата.
  other,
}

/// Ошибка, пришедшая из браузера по возвращении в приложение.
class AccountFailure {
  const AccountFailure(this.kind, {this.detail});

  final AccountFailureKind kind;

  /// Техническое описание для логов, не для показа.
  final String? detail;

  @override
  String toString() => 'AccountFailure($kind, $detail)';
}
