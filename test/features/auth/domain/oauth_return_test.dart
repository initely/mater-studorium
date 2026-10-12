// isOAuthReturnUri: что считается возвратом из Google (ревью безопасности
// T21, B2). Подложенная ссылка с чужими токенами не должна меняться местами с
// сессией человека.
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/auth/domain/oauth_return.dart';

void main() {
  const scheme = 'app.materstudorium.mater-studorium';
  final android = Uri.parse('$scheme://login-callback');
  final web = Uri.parse('http://localhost:3000/');
  final webSub = Uri.parse('https://user.github.io/mater_studorium/');

  bool ok(String url, {Uri? expected}) =>
      isOAuthReturnUri(Uri.parse(url), expected: expected ?? android);

  group('нормальный возврат принимается', () {
    test('Android: code в query', () {
      expect(ok('$scheme://login-callback?code=abc'), isTrue);
    });

    test('Android: слэш в конце пути', () {
      expect(ok('$scheme://login-callback/?code=abc'), isTrue);
    });

    test('Android: ошибка в query (error_code, error, error_description)', () {
      expect(
        ok('$scheme://login-callback?error_code=identity_already_exists'),
        isTrue,
      );
      expect(ok('$scheme://login-callback?error=access_denied'), isTrue);
      expect(ok('$scheme://login-callback?error_description=x'), isTrue);
    });

    test('Android: ошибка во фрагменте (так отдаёт GoTrue)', () {
      expect(
        ok(
          '$scheme://login-callback#error=server_error&error_code=identity_already_exists',
        ),
        isTrue,
      );
    });

    test('Android: query и фрагмент вместе', () {
      expect(ok('$scheme://login-callback?code=a#error=x'), isTrue);
    });

    test('Android: регистр схемы и хоста не важен', () {
      expect(ok('${scheme.toUpperCase()}://LOGIN-CALLBACK?code=a'), isTrue);
    });

    test('web: свой origin и путь, code и ошибка', () {
      expect(ok('http://localhost:3000/?code=abc', expected: web), isTrue);
      expect(ok('http://localhost:3000?code=abc', expected: web), isTrue);
      expect(ok('http://localhost:3000/#error=x', expected: web), isTrue);
      expect(
        ok('https://user.github.io/mater_studorium/?code=a', expected: webSub),
        isTrue,
      );
    });
  });

  group('подмена сессии токенами отклоняется', () {
    final bad = <String, String>{
      'access_token во фрагменте':
          '$scheme://login-callback#access_token=x&refresh_token=y&expires_in=3600&token_type=bearer',
      'access_token в query':
          '$scheme://login-callback?access_token=x&refresh_token=y',
      'только refresh_token во фрагменте':
          '$scheme://login-callback#refresh_token=y',
      'provider_token': '$scheme://login-callback?code=a&provider_token=x',
      'provider_refresh_token':
          '$scheme://login-callback#provider_refresh_token=x&error=y',
      'токены вместе с code': '$scheme://login-callback?code=a#access_token=x',
      'токены вместе с error':
          '$scheme://login-callback?error=a&access_token=x',
      'ключ в верхнем регистре':
          '$scheme://login-callback#ACCESS_TOKEN=x&error=a',
      'ключ закодирован': '$scheme://login-callback#access%5Ftoken=x&code=a',
      'токен после маршрута во фрагменте':
          '$scheme://login-callback#/settings&access_token=x&code=a',
    };
    for (final e in bad.entries) {
      test('Android: ${e.key}', () => expect(ok(e.value), isFalse));
    }

    test('web: токены во фрагменте и в query', () {
      expect(
        ok(
          'http://localhost:3000/#access_token=x&refresh_token=y',
          expected: web,
        ),
        isFalse,
      );
      expect(
        ok('http://localhost:3000/?access_token=x&code=a', expected: web),
        isFalse,
      );
    });
  });

  group('чужой адрес и адрес без признаков возврата отклоняются', () {
    test('чужая схема', () {
      expect(ok('evil://login-callback?code=a'), isFalse);
      expect(ok('$scheme.evil://login-callback?code=a'), isFalse);
    });

    test('чужой хост и путь', () {
      expect(ok('$scheme://other?code=a'), isFalse);
      expect(ok('$scheme://login-callback/extra?code=a'), isFalse);
    });

    test('web: чужой origin, порт, схема, путь', () {
      expect(ok('http://evil.example/?code=a', expected: web), isFalse);
      expect(ok('http://localhost:4000/?code=a', expected: web), isFalse);
      expect(ok('https://localhost:3000/?code=a', expected: web), isFalse);
      expect(
        ok('https://user.github.io/other/?code=a', expected: webSub),
        isFalse,
      );
    });

    test('нет ни code, ни ошибки', () {
      expect(ok('$scheme://login-callback'), isFalse);
      expect(ok('$scheme://login-callback?foo=bar#baz=1'), isFalse);
      expect(ok('$scheme://login-callback#/settings'), isFalse);
      expect(ok('http://localhost:3000/', expected: web), isFalse);
    });

    test('сломанная кодировка не роняет разбор', () {
      expect(
        () => ok('$scheme://login-callback#code=%E0%A4%A'),
        returnsNormally,
      );
      expect(
        () => ok('$scheme://login-callback#%ZZ=1&code=a'),
        returnsNormally,
      );
      expect(() => ok('$scheme://login-callback?%=1'), returnsNormally);
    });
  });
}
