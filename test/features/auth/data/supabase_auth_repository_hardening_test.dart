// Проверка адреса входа и разбор кодов ошибок (ревью безопасности T21, N3, N4).
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/auth/data/supabase_auth_repository.dart';
import 'package:mater_studorium/features/auth/domain/account_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

class _MockGoTrue extends Mock implements GoTrueClient {}

void main() {
  final cloud = Uri.parse('https://abcd.supabase.co');
  final local = Uri.parse('http://127.0.0.1:54321');

  group('isTrustedAuthUrl', () {
    final cases = <String, (String, Uri?, bool)>{
      'Google по https': (
        'https://accounts.google.com/o/oauth2/v2/auth?x=1',
        cloud,
        true,
      ),
      'свой сервер по https': (
        'https://abcd.supabase.co/auth/v1/authorize?p=google',
        cloud,
        true,
      ),
      'локальный стек по http': (
        'http://127.0.0.1:54321/auth/v1/authorize',
        local,
        true,
      ),
      'localhost при SUPABASE_URL на localhost': (
        'http://localhost:54321/auth/v1/authorize',
        Uri.parse('http://localhost:54321'),
        true,
      ),
      'Google по http': ('http://accounts.google.com/', cloud, false),
      'чужой хост по https': ('https://evil.example/auth', cloud, false),
      'похожий хост Google': (
        'https://accounts.google.com.evil.example/',
        cloud,
        false,
      ),
      'поддомен своего сервера': ('https://x.abcd.supabase.co/', cloud, false),
      'свой хост, другой порт': ('http://127.0.0.1:9999/auth', local, false),
      'http к облачному хосту': ('http://abcd.supabase.co/auth', cloud, false),
      'http к постороннему IP при локальном URL': (
        'http://10.1.2.3:54321/auth',
        local,
        false,
      ),
      'http к loopback, но SUPABASE_URL облачный': (
        'http://127.0.0.1:54321/auth',
        cloud,
        false,
      ),
      'схема javascript': ('javascript:alert(1)', cloud, false),
      'схема file': ('file:///etc/passwd', cloud, false),
      'логин в адресе': ('https://user@accounts.google.com/', cloud, false),
      'SUPABASE_URL неизвестен, Google ок': (
        'https://accounts.google.com/',
        null,
        true,
      ),
      'SUPABASE_URL неизвестен, чужой': (
        'https://abcd.supabase.co/',
        null,
        false,
      ),
    };
    for (final e in cases.entries) {
      test(e.key, () {
        final (url, supabase, expected) = e.value;
        expect(
          isTrustedAuthUrl(Uri.parse(url), supabaseUrl: supabase),
          expected,
        );
      });
    }
  });

  group('репозиторий не открывает недоверенный адрес', () {
    late _MockGoTrue auth;
    late List<Uri> launched;

    SupabaseAuthRepository repo({Uri? supabaseUrl}) => SupabaseAuthRepository(
      auth,
      redirectTo: () => 'app.example://cb',
      launcher: (u) async {
        launched.add(u);
        return true;
      },
      supabaseUrl: supabaseUrl ?? cloud,
    );

    setUp(() {
      auth = _MockGoTrue();
      launched = [];
    });

    test(
      'привязка: чужой адрес от сервера -> AuthError, браузер не открыт',
      () async {
        when(
          () => auth.getLinkIdentityUrl(
            OAuthProvider.google,
            redirectTo: any(named: 'redirectTo'),
          ),
        ).thenAnswer(
          (_) async => const OAuthResponse(
            provider: OAuthProvider.google,
            url: 'https://evil.example/phish',
          ),
        );

        await expectLater(repo().linkGoogle(), throwsA(isA<AuthError>()));
        expect(launched, isEmpty);
      },
    );

    test('вход: чужой адрес -> AuthError, браузер не открыт', () async {
      when(
        () => auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer(
        (_) async => const OAuthResponse(
          provider: OAuthProvider.google,
          url: 'http://accounts.google.com/',
        ),
      );

      await expectLater(repo().signInWithGoogle(), throwsA(isA<AuthError>()));
      expect(launched, isEmpty);
    });

    test('вход: адрес своего сервера открывается', () async {
      when(
        () => auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer(
        (_) async => const OAuthResponse(
          provider: OAuthProvider.google,
          url: 'http://127.0.0.1:54321/auth/v1/authorize?provider=google',
        ),
      );

      await repo(supabaseUrl: local).signInWithGoogle();

      expect(launched.single.host, '127.0.0.1');
    });
  });

  group(
    'mapAuthLaunchError: validation_failed не равен «не настроено» (N3)',
    () {
      test('validation_failed с другим текстом -> AuthError', () {
        final e = mapAuthLaunchError(
          'x',
          const AuthApiException(
            'redirect_to is not a valid url',
            statusCode: '400',
            code: 'validation_failed',
          ),
        );
        expect(e, isA<AuthError>());
      });

      test('validation_failed с текстом про провайдера -> «не настроено»', () {
        final e = mapAuthLaunchError(
          'x',
          const AuthApiException(
            'Unsupported provider: provider is not enabled',
            statusCode: '400',
            code: 'validation_failed',
          ),
        );
        expect(e, isA<ProviderUnavailableError>());
      });

      test(
        'только текст «Unsupported provider» без кода -> «не настроено»',
        () {
          expect(
            mapAuthLaunchError(
              'x',
              const AuthException('Unsupported provider: foo'),
            ),
            isA<ProviderUnavailableError>(),
          );
        },
      );
    },
  );

  group(
    'accountFailureFor: код в одном поле при нейтральном сообщении (N3)',
    () {
      AccountFailureKind? kind(AuthException e) => accountFailureFor(e)?.kind;

      test('identity_already_exists только в statusCode', () {
        expect(
          kind(
            const AuthException(
              'Что-то пошло не так',
              statusCode: 'identity_already_exists',
            ),
          ),
          AccountFailureKind.identityAlreadyExists,
        );
      });

      test('identity_already_exists только в code', () {
        expect(
          kind(
            const AuthException(
              'Что-то пошло не так',
              code: 'identity_already_exists',
            ),
          ),
          AccountFailureKind.identityAlreadyExists,
        );
      });

      test('access_denied только в statusCode и только в code', () {
        expect(
          kind(const AuthException('Что-то', statusCode: 'access_denied')),
          AccountFailureKind.cancelled,
        );
        expect(
          kind(const AuthException('Что-то', code: 'access_denied')),
          AccountFailureKind.cancelled,
        );
      });

      test('нейтральная ошибка -> other', () {
        expect(
          kind(const AuthException('Что-то пошло не так', statusCode: '500')),
          AccountFailureKind.other,
        );
      });
    },
  );
}
