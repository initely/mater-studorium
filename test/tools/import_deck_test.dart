import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/import_deck.dart';
import '../../tools/supabase_deck_backend.dart';
import '../helpers/deck_fixtures.dart';

/// Фейковый сервер: колоды в памяти, журнал вызовов.
class _FakeBackend implements DeckImportBackend {
  _FakeBackend({this.version, this.owners = const {}, this.failUpload = false});

  final int? version;
  final Map<String, String> owners;
  final bool failUpload;
  final calls = <String>[];
  final uploads = <String, List<int>>{};
  final rows = <DeckRow>[];

  @override
  Future<int?> currentVersion(String deckId) async {
    calls.add('currentVersion $deckId');
    return version;
  }

  @override
  Future<Map<String, String>> itemOwners({
    required String excludeDeckId,
  }) async {
    calls.add('itemOwners');
    return owners;
  }

  @override
  Future<void> upload(String path, List<int> bytes) async {
    calls.add('upload $path');
    if (failUpload) throw const ImportBackendException('storage недоступен');
    uploads[path] = bytes;
  }

  @override
  Future<void> upsertRow(DeckRow row) async {
    calls.add('upsertRow ${row.id}');
    rows.add(row);
  }
}

typedef _Result = ({int code, String out, String err});

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('import_deck_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String envFile({
    String url = 'http://127.0.0.1:54321',
    String key = 'service-key',
  }) {
    final file = File(
      '${tmp.path}/.env',
    )..writeAsStringSync('SUPABASE_URL=$url\nSUPABASE_SERVICE_ROLE_KEY=$key\n');
    return file.path;
  }

  Future<_Result> run(
    List<String> args, {
    DeckImportBackend? backend,
    String? env,
  }) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runImportDeck(
      [...args, '--env=${env ?? envFile()}'],
      out: out,
      err: err,
      backendFactory: (url, key) {
        if (backend == null) fail('к серверу обращаться не должны');
        return backend;
      },
    );
    return (code: code, out: out.toString(), err: err.toString());
  }

  group('импорт', () {
    test('approved-колода: файл в Storage, затем строка decks', () async {
      final backend = _FakeBackend(version: 1);
      final r = await run([goodDeckPath], backend: backend);

      expect(r.code, 0, reason: r.err);
      expect(r.out, contains('импортирована версия 2'));
      // Сначала файл, потом строка: клиент не увидит колоду без файла.
      expect(backend.calls, [
        'currentVersion fixture-good',
        'itemOwners',
        'upload fixture-good/v2.json',
        'upsertRow fixture-good',
      ]);
      expect(
        utf8.decode(backend.uploads['fixture-good/v2.json']!),
        File(goodDeckPath).readAsStringSync(),
      );
      final row = backend.rows.single.toJson();
      expect(row['storage_path'], 'fixture-good/v2.json');
      expect(row['item_count'], 3);
      expect(row['visibility'], 'public');
    });

    test('первая загрузка колоды (на сервере её нет)', () async {
      final backend = _FakeBackend();
      final r = await run([goodDeckPath], backend: backend);
      expect(r.code, 0, reason: r.err);
      expect(backend.rows, hasLength(1));
    });
  });

  group('валидация перед импортом', () {
    test('draft-колода без --allow-draft отклоняется (--release)', () async {
      final backend = _FakeBackend();
      final r = await run([sampleDeckPath], backend: backend);
      expect(r.code, 1);
      expect(r.err, contains('approved'));
      expect(backend.calls, isEmpty);
    });

    test('повреждённая колода отклоняется до обращения к серверу', () async {
      final json = readJsonFile(goodDeckPath)..remove('title');
      final file = File('${tmp.path}/bad.json')
        ..writeAsStringSync(jsonEncode(json));
      final backend = _FakeBackend();
      final r = await run([file.path], backend: backend);
      expect(r.code, 1);
      expect(backend.calls, isEmpty);
    });
  });

  group('--allow-draft', () {
    test(
      'локальный Supabase: draft-колода импортируется с предупреждением',
      () async {
        final backend = _FakeBackend();
        final r = await run([
          sampleDeckPath,
          '--allow-draft',
        ], backend: backend);
        expect(r.code, 0, reason: r.err);
        expect(r.out, contains('--allow-draft'));
        expect(backend.uploads.keys, ['sample/v1.json']);
      },
    );

    for (final url in ['http://localhost:54321', 'http://[::1]:54321']) {
      test('локальным считается $url', () async {
        final backend = _FakeBackend();
        final r = await run(
          [sampleDeckPath, '--allow-draft'],
          backend: backend,
          env: envFile(url: url),
        );
        expect(r.code, 0, reason: r.err);
      });
    }

    for (final url in [
      'https://abcdefgh.supabase.co',
      'http://192.168.1.10:54321',
      'http://127.0.0.1.evil.example',
      'http://localhost@evil.example',
      'http://0.0.0.0:54321',
      'https://localhost.evil.example',
    ]) {
      test('не-локальный URL $url: отказ, сервер не затронут', () async {
        final r = await run(
          [sampleDeckPath, '--allow-draft'],
          env: envFile(url: url), // backend = null: любое обращение падает
        );
        expect(r.code, 2);
        expect(r.err, contains('--allow-draft разрешён только'));
      });
    }

    test('отказ идёт до валидации и чтения колоды', () async {
      final r = await run([
        '${tmp.path}/нет-такого-файла.json',
        '--allow-draft',
      ], env: envFile(url: 'https://abcdefgh.supabase.co'));
      expect(r.code, 2);
      expect(r.err, contains('--allow-draft разрешён только'));
    });
  });

  group('отказы', () {
    for (final (current, label) in [
      (2, 'равна текущей'),
      (5, 'меньше текущей'),
    ]) {
      test(
        'версия колоды $label ($current): отказ, ничего не загружено',
        () async {
          final backend = _FakeBackend(version: current);
          final r = await run([goodDeckPath], backend: backend);
          expect(r.code, 1);
          expect(r.err, contains('не больше текущей'));
          expect(backend.calls, ['currentVersion fixture-good']);
        },
      );
    }

    test('item_id уже есть в другой колоде: отказ с перечнем', () async {
      final backend = _FakeBackend(owners: {'t.b': 'other-deck', 'zzz': 'x'});
      final r = await run([goodDeckPath], backend: backend);
      expect(r.code, 1);
      expect(r.err, contains('t.b (колода other-deck)'));
      expect(r.err, isNot(contains('zzz')));
      expect(backend.uploads, isEmpty);
      expect(backend.rows, isEmpty);
    });

    test('item_id из прошлой версии той же колоды — не коллизия', () async {
      // itemOwners исключает саму колоду; фейк возвращает чужое: пусто.
      final backend = _FakeBackend(version: 1);
      final r = await run([goodDeckPath], backend: backend);
      expect(r.code, 0, reason: r.err);
    });

    test('сбой загрузки файла: код 3, строка decks не пишется', () async {
      final backend = _FakeBackend(failUpload: true);
      final r = await run([goodDeckPath], backend: backend);
      expect(r.code, 3);
      expect(r.err, contains('storage недоступен'));
      expect(backend.rows, isEmpty);
    });

    test('нет файла колоды в аргументах: код 2', () async {
      final r = await run([]);
      expect(r.code, 2);
    });

    test('env без ключа: код 2', () async {
      final env = File('${tmp.path}/empty.env')
        ..writeAsStringSync('SUPABASE_URL=http://127.0.0.1:54321\n');
      final r = await run([goodDeckPath], env: env.path);
      expect(r.code, 2);
      expect(r.err, contains('SUPABASE_SERVICE_ROLE_KEY'));
    });

    test('нет env-файла: код 2', () async {
      final r = await run([goodDeckPath], env: '${tmp.path}/nope.env');
      expect(r.code, 2);
    });

    test('не-локальный проект по http: ключ не отправляем', () async {
      final r = await run([
        goodDeckPath,
      ], env: envFile(url: 'http://example.supabase.co'));
      expect(r.code, 2);
      expect(r.err, contains('https'));
    });
  });

  group('parseEnv', () {
    test('комментарии, кавычки, export, пробелы', () {
      final env = parseEnv('''
# комментарий
SUPABASE_URL = "http://127.0.0.1:54321"
export SUPABASE_SERVICE_ROLE_KEY='a=b'

BROKEN
''');
      expect(env, {
        'SUPABASE_URL': 'http://127.0.0.1:54321',
        'SUPABASE_SERVICE_ROLE_KEY': 'a=b',
      });
    });
  });

  group('isLocalSupabaseUrl', () {
    test('только loopback', () {
      expect(isLocalSupabaseUrl('http://127.0.0.1:54321'), isTrue);
      expect(isLocalSupabaseUrl('http://localhost'), isTrue);
      expect(isLocalSupabaseUrl('https://x.supabase.co'), isFalse);
      expect(isLocalSupabaseUrl('not a url'), isFalse);
      expect(isLocalSupabaseUrl(''), isFalse);
    });
  });

  group('SupabaseDeckBackend (REST) против локального HTTP-сервера', () {
    late HttpServer server;
    final seen =
        <
          ({
            String method,
            String uri,
            Map<String, String> headers,
            String body,
          })
        >[];
    late Map<String, ({int status, String body})> responses;

    setUp(() async {
      seen.clear();
      responses = {};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        final body = await utf8.decodeStream(req);
        final headers = <String, String>{};
        req.headers.forEach((k, v) => headers[k] = v.join(','));
        seen.add((
          method: req.method,
          uri: req.uri.toString(),
          headers: headers,
          body: body,
        ));
        final r =
            responses['${req.method} ${req.uri.path}'] ??
            (status: 404, body: 'нет заглушки');
        req.response
          ..statusCode = r.status
          ..write(r.body);
        await req.response.close();
      });
    });

    SupabaseDeckBackend backend(String key) =>
        SupabaseDeckBackend(Uri.parse('http://127.0.0.1:${server.port}'), key);

    test('currentVersion, upload, upsertRow: пути, заголовки, тело', () async {
      responses['GET /rest/v1/decks'] = (status: 200, body: '[{"version": 4}]');
      responses['POST /storage/v1/object/decks/d/v5.json'] = (
        status: 200,
        body: '{}',
      );
      responses['POST /rest/v1/decks'] = (status: 201, body: '');
      final b = backend('jwt-key');

      expect(await b.currentVersion('d'), 4);
      await b.upload('d/v5.json', utf8.encode('{"x":1}'));
      await b.upsertRow(
        const DeckRow(
          id: 'd',
          title: 'T',
          topic: 'k',
          lang: 'ru',
          version: 5,
          itemCount: 2,
        ),
      );

      expect(seen[0].uri, contains('id=eq.d'));
      expect(seen[0].headers['apikey'], 'jwt-key');
      expect(seen[0].headers['authorization'], 'Bearer jwt-key');
      expect(seen[1].headers['x-upsert'], 'true');
      expect(seen[1].headers['content-type'], contains('application/json'));
      expect(seen[1].body, '{"x":1}');
      expect(seen[2].uri, contains('on_conflict=id'));
      expect(seen[2].headers['prefer'], contains('merge-duplicates'));
      expect(jsonDecode(seen[2].body), {
        'id': 'd',
        'title': 'T',
        'topic': 'k',
        'lang': 'ru',
        'version': 5,
        'visibility': 'public',
        'storage_path': 'd/v5.json',
        'item_count': 2,
      });
    });

    test('ключ sb_secret_… уходит только в apikey', () async {
      responses['GET /rest/v1/decks'] = (status: 200, body: '[]');
      expect(await backend('sb_secret_abc').currentVersion('d'), isNull);
      expect(seen.single.headers['apikey'], 'sb_secret_abc');
      expect(seen.single.headers.containsKey('authorization'), isFalse);
    });

    test('itemOwners читает файлы других колод', () async {
      responses['GET /rest/v1/decks'] = (
        status: 200,
        body: '[{"id":"other","storage_path":"other/v3.json"}]',
      );
      responses['GET /storage/v1/object/decks/other/v3.json'] = (
        status: 200,
        body: '{"items":[{"id":"a.b"},{"id":"a.c"}]}',
      );
      expect(await backend('k').itemOwners(excludeDeckId: 'd'), {
        'a.b': 'other',
        'a.c': 'other',
      });
      expect(seen.first.uri, contains('id=neq.d'));
    });

    test('нет файла другой колоды: ошибка, а не пропуск проверки', () async {
      responses['GET /rest/v1/decks'] = (
        status: 200,
        body: '[{"id":"other","storage_path":"other/v3.json"}]',
      );
      await expectLater(
        backend('k').itemOwners(excludeDeckId: 'd'),
        throwsA(isA<ImportBackendException>()),
      );
    });

    test('ответ не 2xx: ImportBackendException', () async {
      responses['POST /rest/v1/decks'] = (status: 403, body: 'forbidden');
      await expectLater(
        backend('k').upsertRow(
          const DeckRow(
            id: 'd',
            title: 'T',
            topic: 'k',
            lang: 'ru',
            version: 1,
            itemCount: 0,
          ),
        ),
        throwsA(
          isA<ImportBackendException>().having(
            (e) => e.message,
            'message',
            contains('403'),
          ),
        ),
      );
    });

    test('сервер недоступен: ImportBackendException', () async {
      final b = backend('k');
      await server.close(force: true);
      await expectLater(
        b.currentVersion('d'),
        throwsA(isA<ImportBackendException>()),
      );
    });
  });
}
