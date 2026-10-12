// Живая проверка защиты от подмены сессии ссылкой (ревью безопасности T21,
// B2) против локального Supabase и настоящего supabase_flutter: адрес
// возврата приходит через канал app_links (как на Android), supabase_flutter
// решает по `detectSessionInUriPredicate`. По умолчанию пропускается (тег live):
//
//   supabase start && supabase db reset
//   eval "$(supabase status -o env | sed 's/^/export /')"
//   LIVE_SUPABASE_URL=$API_URL LIVE_SUPABASE_ANON_KEY=$ANON_KEY \
//   LIVE_SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY flutter test --tags live -j 1 test/integration/account_deeplink_live_test.dart
//
// Для проверки «нормальный возврат обрабатывается» без Google настоящий
// `code` берётся из письма Mailpit (подтверждение почты анонимом по PKCE,
// адрес возврата тот же deep link); Mailpit слушает на порту
// LIVE_SUPABASE_MAILPIT (по умолчанию http://127.0.0.1:54324).
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/supabase/supabase_config.dart';
import 'package:mater_studorium/features/auth/domain/oauth_return.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/memory_pkce_storage.dart';

String? _env(String name) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final url = _env('LIVE_SUPABASE_URL');
  final anonKey = _env('LIVE_SUPABASE_ANON_KEY');
  final serviceKey = _env('LIVE_SUPABASE_SERVICE_KEY');
  final mailpit = _env('LIVE_SUPABASE_MAILPIT') ?? 'http://127.0.0.1:54324';
  final skip = url == null || anonKey == null || serviceKey == null
      ? 'нужны LIVE_SUPABASE_URL, LIVE_SUPABASE_ANON_KEY, LIVE_SUPABASE_SERVICE_KEY '
            'и запущенный локальный Supabase'
      : false;

  const channel = EventChannel('com.llfbandit.app_links/events');
  MockStreamHandlerEventSink? sink;
  final created = <String>[];

  setUp(() {
    if (skip != false) return;
    HttpOverrides.global = null; // настоящая сеть, а не заглушка flutter_test
    sink = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          MockStreamHandler.inline(
            onListen: (_, events) => sink = events,
            onCancel: (_) => sink = null,
          ),
        );
  });

  tearDown(() async {
    if (skip != false) return;
    try {
      await Supabase.instance.dispose();
    } on Object {
      // Не был инициализирован.
    }
    final admin = SupabaseClient(url!, serviceKey!);
    for (final id in created) {
      try {
        await admin.auth.admin.deleteUser(id);
      } on Object {
        // Уже удалён.
      }
    }
    created.clear();
    await admin.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, null);
  });

  Future<void> init({required bool withPredicate}) async {
    await Supabase.initialize(
      url: url!,
      publishableKey: anonKey!,
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: MemoryPkceStorage(),
        detectSessionInUriPredicate: withPredicate
            ? (uri) => isOAuthReturnUri(
                uri,
                expected: Uri.parse(SupabaseConfig.androidRedirectUrl),
              )
            : null,
      ),
    );
  }

  /// Сессия атакующего-анонима, из которой собирается ссылка.
  Future<({String id, String link})> attackerLink() async {
    final attacker = SupabaseClient(url!, anonKey!);
    addTearDown(attacker.dispose);
    final res = await attacker.auth.signInAnonymously();
    created.add(res.user!.id);
    final s = res.session!;
    final fragment =
        'access_token=${s.accessToken}&refresh_token=${s.refreshToken}'
        '&expires_in=3600&token_type=bearer';
    return (
      id: res.user!.id,
      link: '${SupabaseConfig.androidRedirectUrl}#$fragment',
    );
  }

  Future<void> deliver(String link) async {
    // Подписка app_links появляется после `initialize`.
    for (var i = 0; i < 50 && sink == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(sink, isNotNull, reason: 'supabase_flutter не подписался на ссылки');
    sink!.success(link);
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  test('КОНТРОЛЬ без предиката: подложенная ссылка меняет пользователя '
      '(уязвимость до исправления B2)', () async {
    await init(withPredicate: false);
    final victim =
        (await Supabase.instance.client.auth.signInAnonymously()).user!;
    created.add(victim.id);
    final attacker = await attackerLink();

    await deliver(attacker.link);

    expect(
      Supabase.instance.client.auth.currentUser!.id,
      attacker.id,
      reason: 'без фильтра сессия жертвы подменена сессией атакующего',
    );
  }, skip: skip);

  test(
    'с предикатом: подложенная ссылка с токенами НЕ меняет currentUser',
    () async {
      await init(withPredicate: true);
      final victim =
          (await Supabase.instance.client.auth.signInAnonymously()).user!;
      created.add(victim.id);
      final attacker = await attackerLink();

      await deliver(attacker.link);
      expect(Supabase.instance.client.auth.currentUser!.id, victim.id);

      // Те же токены в query, а не во фрагменте.
      await deliver(attacker.link.replaceFirst('#', '?'));
      expect(Supabase.instance.client.auth.currentUser!.id, victim.id);

      // Чужая схема и чужой путь с теми же токенами.
      await deliver(attacker.link.replaceFirst('login-callback', 'other'));
      expect(Supabase.instance.client.auth.currentUser!.id, victim.id);

      // Чужой ?code= безопасен: у приложения нет code_verifier для него.
      await deliver('${SupabaseConfig.androidRedirectUrl}?code=not-ours');
      expect(Supabase.instance.client.auth.currentUser!.id, victim.id);
    },
    skip: skip,
  );

  test(
    'с предикатом: настоящий возврат с code (PKCE) обрабатывается',
    () async {
      await init(withPredicate: true);
      final auth = Supabase.instance.client.auth;
      final anon = (await auth.signInAnonymously()).user!;
      created.add(anon.id);
      final email = 'pkce${DateTime.now().microsecondsSinceEpoch}@example.com';

      // Законная смена почты анонима по PKCE: письмо со ссылкой, GoTrue
      // возвращает на наш deep link с настоящим `code`.
      await auth.updateUser(
        UserAttributes(email: email),
        emailRedirectTo: SupabaseConfig.androidRedirectUrl,
      );
      final verifyLink = await _latestMailLink(mailpit, email);
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(verifyLink))
        ..followRedirects = false;
      final response = await request.close();
      final location = response.headers.value(HttpHeaders.locationHeader);
      client.close(force: true);
      expect(
        location,
        startsWith(SupabaseConfig.androidRedirectUrl),
        reason: 'GoTrue должен вернуть на наш deep link (схема допустима)',
      );
      expect(Uri.parse(location!).queryParameters['code'], isNotNull);
      expect(
        isOAuthReturnUri(
          Uri.parse(location),
          expected: Uri.parse(SupabaseConfig.androidRedirectUrl),
        ),
        isTrue,
      );

      await deliver(location);

      expect(auth.currentUser?.id, anon.id, reason: 'тот же пользователь');
      expect(auth.currentUser?.email, email, reason: 'код обменян на сессию');
    },
    skip: skip,
  );
}

/// Ссылка подтверждения из последнего письма на [email] в Mailpit.
Future<String> _latestMailLink(String mailpit, String email) async {
  final http = HttpClient();
  try {
    for (var i = 0; i < 30; i++) {
      final list = await _getJson(http, '$mailpit/api/v1/messages');
      for (final m in (list['messages'] as List).cast<Map<String, dynamic>>()) {
        final to = (m['To'] as List).map((t) => (t as Map)['Address']);
        if (!to.contains(email)) continue;
        final msg = await _getJson(http, '$mailpit/api/v1/message/${m['ID']}');
        final html = '${msg['HTML']} ${msg['Text']}';
        final match = RegExp(r'https?://[^"\s<>]*auth/v1/verify[^"\s<>]*')
            .firstMatch(html);
        if (match != null) return match.group(0)!.replaceAll('&amp;', '&');
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  } finally {
    http.close(force: true);
  }
  fail('письмо для $email не пришло в Mailpit');
}

Future<Map<String, dynamic>> _getJson(HttpClient http, String url) async {
  final req = await http.getUrl(Uri.parse(url));
  final res = await req.close();
  return jsonDecode(await utf8.decoder.bind(res).join())
      as Map<String, dynamic>;
}
