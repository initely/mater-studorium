import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

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
      throw AuthError('Anonymous sign-in отклонён: ${e.message}', cause: e);
    } catch (e) {
      throw UnexpectedError('Anonymous sign-in: неожиданная ошибка', cause: e);
    }
  }
}
