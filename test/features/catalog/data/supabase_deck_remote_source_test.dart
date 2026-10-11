import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/data/supabase_deck_remote_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _notFoundBody =
    '{"statusCode":"404","error":"not_found","message":"Object not found"}';

typedef _Reply = ({int status, String body});

const _row =
    '{"id":"d","title":"Колода","topic":"infosec","lang":"ru",'
    '"version":3,"item_count":20,"storage_path":"d/v3.json"}';

/// Настоящий клиент Supabase против локального HTTP-сервера: проверяем и пути
/// запросов, и то, как ответы и сбои превращаются в типизированные ошибки.
void main() {
  late HttpServer server;
  late Map<String, _Reply> replies;
  final requests =
      <({String method, String uri, Map<String, String> headers})>[];
  var signedIn = true;

  setUp(() async {
    replies = {};
    requests.clear();
    signedIn = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((req) async {
      final headers = <String, String>{};
      req.headers.forEach((k, v) => headers[k] = v.join(','));
      requests.add((
        method: req.method,
        uri: req.uri.toString(),
        headers: headers,
      ));
      final reply = replies[req.uri.path] ?? (status: 404, body: '{}');
      req.response
        ..statusCode = reply.status
        ..headers.contentType = ContentType.json
        ..write(reply.body);
      await req.response.close();
    });
  });

  SupabaseDeckRemoteSource source({Duration? timeout}) {
    // Короткий таймаут: клиент повторяет запросы при сбоях до его истечения.
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'anon-key',
    );
    addTearDown(client.dispose);
    return SupabaseDeckRemoteSource(
      client,
      timeout: timeout ?? const Duration(milliseconds: 400),
      hasSession: () => signedIn,
    );
  }

  group('успешные ответы', () {
    test('fetchDecks разбирает строки каталога', () async {
      replies['/rest/v1/decks'] = (status: 200, body: '[$_row]');

      final decks = await source().fetchDecks();

      expect(decks.single.id, 'd');
      expect(decks.single.title, 'Колода');
      expect(decks.single.version, 3);
      expect(decks.single.itemCount, 20);
      expect(decks.single.storagePath, 'd/v3.json');
      expect(requests.single.uri, contains('order=title'));
    });

    test('fetchDeck: колода найдена', () async {
      replies['/rest/v1/decks'] = (status: 200, body: '[$_row]');
      expect((await source().fetchDeck('d'))!.version, 3);
      expect(requests.single.uri, contains('id=eq.d'));
    });

    test('fetchDeck: колоды нет (или RLS её не показывает) — null', () async {
      replies['/rest/v1/decks'] = (status: 200, body: '[]');
      expect(await source().fetchDeck('d'), isNull);
    });

    test('downloadDeckFile отдаёт байты из bucket decks', () async {
      replies['/storage/v1/object/decks/d/v3.json'] = (
        status: 200,
        body: '{"schema_version":1}',
      );

      final bytes = await source().downloadDeckFile('d/v3.json');

      expect(utf8.decode(bytes), '{"schema_version":1}');
    });
  });

  group('ошибки превращаются в AppError', () {
    test('нет сессии: NetworkError без запроса к серверу', () async {
      signedIn = false;
      await expectLater(source().fetchDecks(), throwsA(isA<NetworkError>()));
      expect(requests, isEmpty);
    });

    test('сервер недоступен (соединение отклонено): NetworkError', () async {
      final s = source();
      await server.close(force: true);
      await expectLater(s.fetchDecks(), throwsA(isA<NetworkError>()));
      await expectLater(
        s.downloadDeckFile('d/v3.json'),
        throwsA(isA<NetworkError>()),
      );
    });

    test('5xx от шлюза: NetworkError', () async {
      replies['/rest/v1/decks'] = (status: 503, body: 'upstream unavailable');
      await expectLater(source().fetchDecks(), throwsA(isA<NetworkError>()));
    });

    test('отказ RLS (42501): AuthError', () async {
      replies['/rest/v1/decks'] = (
        status: 401,
        body: '{"code":"42501","message":"permission denied for table decks"}',
      );
      await expectLater(source().fetchDecks(), throwsA(isA<AuthError>()));
    });

    test('неверный JWT (PGRST301): AuthError', () async {
      replies['/rest/v1/decks'] = (
        status: 401,
        body: '{"code":"PGRST301","message":"JWT expired"}',
      );
      await expectLater(source().fetchDecks(), throwsA(isA<AuthError>()));
    });

    test('файла нет в Storage: DeckNotFoundError', () async {
      replies['/storage/v1/object/decks/d/v3.json'] = (
        status: 404,
        body: _notFoundBody,
      );
      await expectLater(
        source().downloadDeckFile('d/v3.json'),
        throwsA(isA<DeckNotFoundError>()),
      );
    });

    test('Storage 400 «Object not found»: DeckNotFoundError', () async {
      replies['/storage/v1/object/decks/d/v3.json'] = (
        status: 400,
        body: _notFoundBody,
      );
      await expectLater(
        source().downloadDeckFile('d/v3.json'),
        throwsA(isA<DeckNotFoundError>()),
      );
    });

    test('Storage 5xx: NetworkError', () async {
      replies['/storage/v1/object/decks/d/v3.json'] = (
        status: 502,
        body: '{"statusCode":"502","message":"bad gateway"}',
      );
      await expectLater(
        source().downloadDeckFile('d/v3.json'),
        throwsA(isA<NetworkError>()),
      );
    });

    test('строка каталога неожиданной формы: UnexpectedError', () async {
      replies['/rest/v1/decks'] = (status: 200, body: '[{"id":"d"}]');
      await expectLater(source().fetchDecks(), throwsA(isA<UnexpectedError>()));
    });

    test(
      'mapRemoteError: прочее — UnexpectedError, AppError не переупаковывается',
      () {
        expect(mapRemoteError(StateError('x')), isA<UnexpectedError>());
        expect(
          mapRemoteError(http.ClientException('Failed to fetch')),
          isA<NetworkError>(),
        );
        expect(mapRemoteError(TimeoutException('долго')), isA<NetworkError>());
        const original = NetworkError('n');
        expect(mapRemoteError(original), same(original));
      },
    );
  });
}
