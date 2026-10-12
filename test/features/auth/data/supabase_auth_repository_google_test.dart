// SupabaseAuthRepository: привязка Google и вход через браузер (T21, ADR-34).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/auth/data/supabase_auth_repository.dart';
import 'package:mater_studorium/features/auth/domain/account_failure.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockGoTrueClient auth;
  late List<Uri> launched;
  var launchResult = true;
  late SupabaseAuthRepository repo;

  setUp(() {
    auth = MockGoTrueClient();
    launched = [];
    launchResult = true;
    repo = SupabaseAuthRepository(
      auth,
      redirectTo: () => 'app.example://callback',
      launcher: (url) async {
        launched.add(url);
        return launchResult;
      },
    );
  });

  group('linkGoogle', () {
    test('берёт адрес привязки у GoTrue и открывает его в браузере', () async {
      when(
        () => auth.getLinkIdentityUrl(
          OAuthProvider.google,
          redirectTo: 'app.example://callback',
        ),
      ).thenAnswer(
        (_) async => const OAuthResponse(
          provider: OAuthProvider.google,
          url: 'https://accounts.example/authorize?state=1',
        ),
      );

      await repo.linkGoogle();

      expect(launched, [
        Uri.parse('https://accounts.example/authorize?state=1'),
      ]);
    });

    test('браузер не открылся: UnexpectedError', () async {
      when(
        () => auth.getLinkIdentityUrl(
          OAuthProvider.google,
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer(
        (_) async => const OAuthResponse(
          provider: OAuthProvider.google,
          url: 'https://x.example/',
        ),
      );
      launchResult = false;

      expect(repo.linkGoogle(), throwsA(isA<UnexpectedError>()));
    });

    for (final (name, error, matcher) in <(String, AuthException, Matcher)>[
      (
        'провайдер выключен (validation_failed)',
        const AuthApiException(
          'Unsupported provider: provider is not enabled',
          statusCode: '400',
          code: 'validation_failed',
        ),
        isA<ProviderUnavailableError>(),
      ),
      (
        'ручное связывание выключено',
        const AuthApiException(
          'Manual linking is disabled',
          statusCode: '404',
          code: 'manual_linking_disabled',
        ),
        isA<ProviderUnavailableError>(),
      ),
      (
        'сеть',
        AuthRetryableFetchException(message: 'Failed host lookup'),
        isA<NetworkError>(),
      ),
      (
        'лимит запросов',
        const AuthApiException(
          'slow',
          statusCode: '429',
          code: 'over_request_rate_limit',
        ),
        isA<NetworkError>(),
      ),
      (
        'отказ сервера',
        const AuthApiException('nope', statusCode: '403', code: 'forbidden'),
        isA<AuthError>(),
      ),
    ]) {
      test('ошибка GoTrue: $name', () {
        when(
          () => auth.getLinkIdentityUrl(
            OAuthProvider.google,
            redirectTo: any(named: 'redirectTo'),
          ),
        ).thenThrow(error);

        expect(repo.linkGoogle(), throwsA(matcher));
        expect(launched, isEmpty);
      });
    }

    test('неожиданное исключение: UnexpectedError', () {
      when(
        () => auth.getLinkIdentityUrl(
          OAuthProvider.google,
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenThrow(StateError('boom'));

      expect(repo.linkGoogle(), throwsA(isA<UnexpectedError>()));
    });
  });

  group('signInWithGoogle', () {
    test('открывает адрес обычного входа (не привязки)', () async {
      when(
        () => auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: 'app.example://callback',
        ),
      ).thenAnswer(
        (_) async => const OAuthResponse(
          provider: OAuthProvider.google,
          url: 'https://accounts.example/signin',
        ),
      );

      await repo.signInWithGoogle();

      expect(launched, [Uri.parse('https://accounts.example/signin')]);
      verifyNever(
        () => auth.getLinkIdentityUrl(
          OAuthProvider.google,
          redirectTo: any(named: 'redirectTo'),
        ),
      );
    });
  });

  group('oauthFailures', () {
    late StreamController<AuthState> states;
    setUp(() {
      states = StreamController<AuthState>.broadcast();
      addTearDown(states.close);
      when(() => auth.onAuthStateChange).thenAnswer((_) => states.stream);
    });

    Future<List<AccountFailure>> collect(List<Object> errors) async {
      final out = <AccountFailure>[];
      final sub = repo.oauthFailures().listen(out.add);
      await Future<void>.delayed(Duration.zero);
      for (final e in errors) {
        states.addError(e);
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      return out;
    }

    test('identity_already_exists в statusCode (так собирает gotrue из адреса '
        'возврата)', () async {
      final out = await collect([
        const AuthException(
          'Identity is already linked to another user',
          statusCode: 'identity_already_exists',
          code: 'server_error',
        ),
      ]);

      expect(out.single.kind, AccountFailureKind.identityAlreadyExists);
    });

    test('identity_already_exists в code и в тексте', () async {
      final out = await collect([
        const AuthApiException(
          'x',
          statusCode: '422',
          code: 'identity_already_exists',
        ),
        const AuthException('Identity is already linked to another user'),
      ]);

      expect(out.map((f) => f.kind), [
        AccountFailureKind.identityAlreadyExists,
        AccountFailureKind.identityAlreadyExists,
      ]);
    });

    test('отказ в Google: access_denied', () async {
      final out = await collect([
        const AuthException(
          'The user denied',
          statusCode: '',
          code: 'access_denied',
        ),
      ]);

      expect(out.single.kind, AccountFailureKind.cancelled);
    });

    test('другая ошибка возврата: other', () async {
      final out = await collect([
        const AuthException(
          'bad callback',
          statusCode: 'bad_oauth_callback',
          code: 'invalid_request',
        ),
      ]);

      expect(out.single.kind, AccountFailureKind.other);
    });

    test(
      'сетевой сбой обновления токена и посторонние ошибки не события',
      () async {
        final out = await collect([
          AuthRetryableFetchException(message: 'offline'),
          StateError('boom'),
        ]);

        expect(out, isEmpty);
      },
    );

    test('обычные события входа не ошибки', () async {
      final out = <AccountFailure>[];
      final sub = repo.oauthFailures().listen(out.add);
      await Future<void>.delayed(Duration.zero);
      states.add(const AuthState(AuthChangeEvent.signedIn, null));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(out, isEmpty);
    });
  });

  group('пользователь', () {
    test('userChanges отдаёт почту привязанного аккаунта; смена anonymous -> '
        'Google при том же id — новое событие', () async {
      final states = StreamController<AuthState>.broadcast();
      addTearDown(states.close);
      when(() => auth.onAuthStateChange).thenAnswer((_) => states.stream);
      final out = <AuthUser?>[];
      final sub = repo.userChanges().listen(out.add);

      Session session({required bool anonymous, String? email}) => Session(
        accessToken: 't',
        tokenType: 'bearer',
        user: User(
          id: 'u1',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-10-12T10:00:00Z',
          isAnonymous: anonymous,
          email: email,
        ),
      );
      states.add(AuthState(AuthChangeEvent.signedIn, session(anonymous: true)));
      states.add(
        AuthState(AuthChangeEvent.tokenRefreshed, session(anonymous: true)),
      );
      states.add(
        AuthState(
          AuthChangeEvent.userUpdated,
          session(anonymous: false, email: 'me@example.com'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(out, hasLength(2), reason: 'обновление токена не событие');
      expect(out.first!.isAnonymous, isTrue);
      expect(out.last, const AuthUser(id: 'u1', isAnonymous: false));
      expect(out.last!.email, 'me@example.com');
    });
  });

  group('accountFailureFor', () {
    test('не AuthException: null', () {
      expect(accountFailureFor(StateError('x')), isNull);
    });
  });
}
