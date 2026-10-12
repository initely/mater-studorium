/// Вошедший пользователь: только то, что нужно приложению.
class AuthUser {
  const AuthUser({required this.id, required this.isAnonymous});

  /// `auth.uid()`; им помечены строки локальной БД.
  final String id;

  /// Анонимный вход (ТЗ M1): такой аккаунт нельзя «войти заново», если его
  /// сессия потеряна.
  final bool isAnonymous;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.isAnonymous == isAnonymous;

  @override
  int get hashCode => Object.hash(id, isAnonymous);

  @override
  String toString() => 'AuthUser($id, anonymous: $isAnonymous)';
}
