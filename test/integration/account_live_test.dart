// Живая проверка T21 против локального Supabase: всё, что можно проверить без
// ключей Google. По умолчанию пропускается (тег live):
//
//   supabase start && supabase db reset
//   eval "$(supabase status -o env | sed 's/^/export /')"
//   LIVE_SUPABASE_URL=$API_URL LIVE_SUPABASE_ANON_KEY=$ANON_KEY \
//   LIVE_SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY flutter test --tags live -j 1 test/integration/account_live_test.dart
//
// Проверяется:
// 1. анонимный вход работает при `enable_manual_linking = true` и
//    `[auth.email] enable_signup = false` (config.toml, ADR-34);
// 2. привязка Google через настоящий GoTrue: пока провайдер выключен,
//    `linkGoogle()` даёт `ProviderUnavailableError`, браузер не открывается;
//    если вы уже включили Google (README), адрес ведёт на accounts.google.com;
// 3. пробный запуск чистки сиротских анонимов видит старого пустого аноним-
//    ного пользователя и не видит молодого и того, у кого есть данные.
//    Удаляющий запуск здесь не выполняется (он тронул бы чужих анонимов в
//    вашей локальной БД); его проверяет pgTAP 0006.
// Возраст пользователей ставится через `docker exec <контейнер БД> psql`
// (LIVE_SUPABASE_DB_CONTAINER, по умолчанию supabase_db_mater_studorium).
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/supabase/supabase_config.dart';
import 'package:mater_studorium/features/auth/data/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/memory_pkce_storage.dart';

String? _env(String name) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : value;
}

void main() {
  final url = _env('LIVE_SUPABASE_URL');
  final anonKey = _env('LIVE_SUPABASE_ANON_KEY');
  final serviceKey = _env('LIVE_SUPABASE_SERVICE_KEY');
  final container =
      _env('LIVE_SUPABASE_DB_CONTAINER') ?? 'supabase_db_mater_studorium';
  final skip = url == null || anonKey == null || serviceKey == null
      ? 'нужны LIVE_SUPABASE_URL, LIVE_SUPABASE_ANON_KEY, LIVE_SUPABASE_SERVICE_KEY '
            'и запущенный локальный Supabase'
      : false;

  late SupabaseClient admin;
  final clients = <SupabaseClient>[];
  final created = <String>[];

  void liveTest(String name, Future<void> Function() body) =>
      test(name, body, skip: skip);

  Future<({SupabaseClient client, String id})> newAnonymous() async {
    // PKCE (как в приложении) требует хранилища проверочного кода.
    final client = SupabaseClient(
      url!,
      anonKey!,
      authOptions: AuthClientOptions(pkceAsyncStorage: MemoryPkceStorage()),
    );
    clients.add(client);
    final res = await client.auth.signInAnonymously();
    final user = res.user!;
    created.add(user.id);
    return (client: client, id: user.id);
  }

  Future<String> psql(String sql) async {
    final r = await Process.run('docker', [
      'exec',
      container,
      'psql',
      '-U',
      'postgres',
      '-tA',
      '-c',
      sql,
    ]);
    if (r.exitCode != 0) fail('psql: ${r.stderr}');
    return (r.stdout as String).trim();
  }

  setUp(() {
    if (skip != false) return;
    admin = SupabaseClient(url!, serviceKey!);
  });

  tearDown(() async {
    if (skip != false) return;
    for (final c in clients) {
      await c.dispose();
    }
    clients.clear();
    for (final id in created) {
      try {
        await admin.auth.admin.deleteUser(id);
      } on Object {
        // Уже удалён.
      }
    }
    created.clear();
    await admin.dispose();
  });

  liveTest(
    'анонимный вход работает с manual linking и без email signup',
    () async {
      final a = await newAnonymous();

      expect(a.client.auth.currentUser!.isAnonymous, isTrue);
      expect(a.client.auth.currentSession, isNotNull);
    },
  );

  liveTest('linkGoogle через настоящий GoTrue: Google выключен -> '
      '«не настроено», включён -> адрес Google', () async {
    final a = await newAnonymous();
    final opened = <Uri>[];
    final repo = SupabaseAuthRepository(
      a.client.auth,
      redirectTo: () => 'http://localhost:3000/',
      launcher: (u) async {
        opened.add(u);
        return true;
      },
    );

    Object? error;
    try {
      await repo.linkGoogle();
    } on Object catch (e) {
      error = e;
    }

    if (error == null) {
      // Провайдер включён (вы настроили ключи по README).
      expect(opened.single.host, 'accounts.google.com');
      expect(
        opened.single.queryParameters['redirect_uri'],
        contains('/auth/v1/callback'),
      );
    } else {
      expect(
        error,
        isA<ProviderUnavailableError>(),
        reason: '$error cause=${(error as AppError).cause}',
      );
      expect(opened, isEmpty);
    }
    // Пользователь остался анонимным: ничего не сломалось.
    expect(a.client.auth.currentUser!.isAnonymous, isTrue);
  });

  liveTest('адрес возврата Android доходит до GoTrue (B1): flow_state.referrer '
      '== androidRedirectUrl для привязки и для входа (нужен включённый Google, '
      'иначе пропускается)', () async {
    final a = await newAnonymous();
    final opened = <Uri>[];
    final repo = SupabaseAuthRepository(
      a.client.auth,
      supabaseUrl: Uri.parse(url!),
      launcher: (u) async {
        opened.add(u);
        return true;
      },
    );
    try {
      await repo.linkGoogle();
    } on ProviderUnavailableError {
      markTestSkipped('Google выключен: flow_state не создаётся');
      return;
    }
    await repo.signInWithGoogle();
    // Адрес входа строится на клиенте; flow_state появляется, когда браузер
    // открывает его (GoTrue отвечает редиректом на Google).
    final http = HttpClient();
    final req = await http.getUrl(opened.last)
      ..followRedirects = false;
    final res = await req.close();
    await res.drain<void>();
    http.close(force: true);

    final referrers = (await psql(
      'select referrer from auth.flow_state order by created_at desc limit 2',
    )).split('\n');
    expect(opened, hasLength(2));
    expect(referrers, [
      SupabaseConfig.androidRedirectUrl,
      SupabaseConfig.androidRedirectUrl,
    ], reason: 'иначе GoTrue отбросил redirect_to и подставил site_url');
  });

  liveTest('чистка (пробный запуск): старый пустой аноним виден, молодой и с '
      'данными нет', () async {
    final oldEmpty = await newAnonymous();
    final young = await newAnonymous();
    final withData = await newAnonymous();
    // У withData есть состояние знания на сервере (через RPC синка).
    await withData.client.rpc<dynamic>(
      'upsert_item_states',
      params: {
        'p_user_id': withData.id,
        'p_states': [
          {
            'item_id': 'live.t21',
            'deck_id': 'live',
            'due': DateTime.now().toUtc().toIso8601String(),
            'stability': 1,
            'difficulty': 5,
            'elapsed_days': 0,
            'scheduled_days': 1,
            'reps': 1,
            'lapses': 0,
            'state': 2,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      },
    );
    await psql(
      "update auth.users set created_at = now() - interval '40 days' "
      "where id in ('${oldEmpty.id}', '${withData.id}')",
    );
    await psql(
      "update auth.sessions set created_at = now() - interval '40 days', "
      "updated_at = now() - interval '40 days', "
      "refreshed_at = now() - interval '40 days' "
      "where user_id in ('${oldEmpty.id}', '${withData.id}')",
    );

    final candidates = (await psql(
      'select user_id from private.purge_orphan_anonymous_users()',
    )).split('\n');

    expect(candidates, contains(oldEmpty.id));
    expect(candidates, isNot(contains(young.id)));
    expect(candidates, isNot(contains(withData.id)));
    // Пробный запуск ничего не удалил.
    expect(
      await psql("select count(*) from auth.users where id = '${oldEmpty.id}'"),
      '1',
    );
  });
}
