import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/auth/data/supabase_auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

void main() {
  late MockGoTrueClient auth;
  late SupabaseAuthRepository repo;

  setUp(() {
    auth = MockGoTrueClient();
    repo = SupabaseAuthRepository(auth);
    when(() => auth.currentSession).thenReturn(null);
  });

  test('есть сессия: повторный анонимный вход не выполняется', () async {
    when(() => auth.currentSession).thenReturn(MockSession());

    await repo.ensureSignedIn();

    verifyNever(() => auth.signInAnonymously());
  });

  test('нет сессии: выполняется анонимный вход', () async {
    when(() => auth.signInAnonymously())
        .thenAnswer((_) async => AuthResponse());

    await repo.ensureSignedIn();

    verify(() => auth.signInAnonymously()).called(1);
  });

  test('сетевой сбой превращается в NetworkError', () {
    when(() => auth.signInAnonymously())
        .thenThrow(AuthRetryableFetchException(message: 'Failed host lookup'));

    expect(repo.ensureSignedIn(), throwsA(isA<NetworkError>()));
  });

  test('лимит запросов (429) превращается в NetworkError для повтора', () {
    when(() => auth.signInAnonymously()).thenThrow(
      const AuthApiException(
        'Request rate limit reached',
        statusCode: '429',
        code: 'over_request_rate_limit',
      ),
    );

    expect(repo.ensureSignedIn(), throwsA(isA<NetworkError>()));
  });

  test('429 без кода тоже NetworkError', () {
    when(() => auth.signInAnonymously())
        .thenThrow(const AuthException('slow down', statusCode: '429'));

    expect(repo.ensureSignedIn(), throwsA(isA<NetworkError>()));
  });

  test('отказ сервера превращается в AuthError', () {
    when(() => auth.signInAnonymously()).thenThrow(
      const AuthApiException(
        'Anonymous sign-ins are disabled',
        statusCode: '422',
        code: 'anonymous_provider_disabled',
      ),
    );

    expect(repo.ensureSignedIn(), throwsA(isA<AuthError>()));
  });

  test('неожиданное исключение превращается в UnexpectedError', () {
    when(() => auth.signInAnonymously()).thenThrow(StateError('boom'));

    expect(repo.ensureSignedIn(), throwsA(isA<UnexpectedError>()));
  });
}
