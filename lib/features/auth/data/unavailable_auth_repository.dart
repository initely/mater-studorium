import '../../../core/errors/app_error.dart';
import '../domain/account_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Вход, когда Supabase не инициализирован: любая попытка — `NetworkError`.
/// Для `AuthSessionNotifier` это «нет сети»: он повторяет попытку с паузами.
final class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  static const _error = NetworkError('Supabase недоступен');

  @override
  Future<void> ensureSignedIn() => Future.error(_error);

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> userChanges() => const Stream.empty();

  @override
  Future<void> linkGoogle() => Future.error(_error);

  @override
  Future<void> signInWithGoogle() => Future.error(_error);

  @override
  Stream<AccountFailure> oauthFailures() => const Stream.empty();
}
