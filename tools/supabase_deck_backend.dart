// Сервер для tools/import_deck.dart: PostgREST (`decks`) и Storage (bucket
// `decks`) по REST с ключом service role. Только dart:io, без пакетов Supabase.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Строка таблицы `decks`, которую пишет импорт (`owner_id` = null: колоды
/// куратора, `visibility` = public).
final class DeckRow {
  const DeckRow({
    required this.id,
    required this.title,
    required this.topic,
    required this.lang,
    required this.version,
    required this.itemCount,
  });

  final String id;
  final String title;
  final String topic;
  final String lang;
  final int version;
  final int itemCount;

  /// Путь объекта внутри bucket `decks` (совпадает с CHECK в миграции).
  String get storagePath => '$id/v$version.json';

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'topic': topic,
    'lang': lang,
    'version': version,
    'visibility': 'public',
    'storage_path': storagePath,
    'item_count': itemCount,
  };
}

/// Колода, уже лежащая на сервере.
final class ExistingDeck {
  const ExistingDeck({
    required this.version,
    this.ownerId,
    this.visibility = 'public',
  });

  final int version;

  /// null — колода куратора.
  final String? ownerId;
  final String visibility;
}

/// Доступ к серверу, нужный импорту. В тестах заменяется фейком.
abstract interface class DeckImportBackend {
  /// Колода на сервере или null, если её нет.
  Future<ExistingDeck?> existingDeck(String deckId);

  /// id знаний и id вопросов → id колоды для всех колод, кроме [excludeDeckId]
  /// (текущие версии их файлов). И знания, и вопросы глобально уникальны
  /// между колодами (ADR-21: общий PK `questions.id` в локальной БД).
  Future<Map<String, String>> itemOwners({required String excludeDeckId});

  /// Кладёт файл в bucket `decks`.
  Future<void> upload(String path, List<int> bytes);

  /// Upsert строки `decks`.
  Future<void> upsertRow(DeckRow row);
}

/// Ошибка сервера или сети при импорте.
final class ImportBackendException implements Exception {
  const ImportBackendException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _timeout = Duration(seconds: 30);

/// REST-реализация [DeckImportBackend]. [baseUrl] — корень проекта
/// (`http://127.0.0.1:54321`), [serviceKey] — ключ service role.
final class SupabaseDeckBackend implements DeckImportBackend {
  SupabaseDeckBackend(this.baseUrl, this._serviceKey);

  final Uri baseUrl;
  final String _serviceKey;

  Uri _uri(String path, [Map<String, String>? query]) => baseUrl.replace(
    path: '${baseUrl.path.replaceAll(RegExp(r'/+$'), '')}$path',
    queryParameters: query,
  );

  Map<String, String> get _auth => {
    'apikey': _serviceKey,
    // Новые ключи `sb_secret_…` не JWT: их шлют только в apikey.
    if (!_serviceKey.startsWith('sb_')) 'Authorization': 'Bearer $_serviceKey',
  };

  Future<(int, List<int>)> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.openUrl(method, uri).timeout(_timeout);
      // Редиректы не идём: HttpClient переслал бы apikey и Authorization (ключ
      // service role) на другой хост. Любой 3xx — ошибка (см. ниже).
      request.followRedirects = false;
      _auth.forEach(request.headers.set);
      headers.forEach(request.headers.set);
      if (body != null) request.add(body);
      final response = await request.close().timeout(_timeout);
      final bytes = await response
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk))
          .timeout(_timeout);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw ImportBackendException(
          'сервер ответил редиректом (HTTP ${response.statusCode}) на '
          '$method ${uri.replace(query: '')}: редиректы не поддерживаются, '
          'проверь SUPABASE_URL',
        );
      }
      return (response.statusCode, bytes);
    } on SocketException catch (e) {
      throw ImportBackendException('нет соединения с $baseUrl: ${e.message}');
    } on HttpException catch (e) {
      throw ImportBackendException('ошибка HTTP $method $uri: ${e.message}');
    } on TimeoutException {
      throw ImportBackendException('таймаут $method $uri');
    } finally {
      client.close(force: true);
    }
  }

  Never _fail(String what, int status, List<int> body) {
    final text = utf8.decode(body, allowMalformed: true);
    final short = text.length <= 300 ? text : '${text.substring(0, 300)}…';
    throw ImportBackendException('$what: HTTP $status $short');
  }

  @override
  Future<ExistingDeck?> existingDeck(String deckId) async {
    final (status, body) = await _send(
      'GET',
      _uri('/rest/v1/decks', {
        'select': 'version,owner_id,visibility',
        'id': 'eq.$deckId',
      }),
    );
    if (status != 200) _fail('чтение decks', status, body);
    final rows = jsonDecode(utf8.decode(body)) as List<dynamic>;
    if (rows.isEmpty) return null;
    final row = rows.single as Map<String, dynamic>;
    return ExistingDeck(
      version: row['version'] as int,
      ownerId: row['owner_id'] as String?,
      visibility: row['visibility'] as String,
    );
  }

  @override
  Future<Map<String, String>> itemOwners({
    required String excludeDeckId,
  }) async {
    final (status, body) = await _send(
      'GET',
      _uri('/rest/v1/decks', {
        'select': 'id,storage_path',
        'id': 'neq.$excludeDeckId',
      }),
    );
    if (status != 200) _fail('чтение decks', status, body);
    final owners = <String, String>{};
    for (final row in jsonDecode(utf8.decode(body)) as List<dynamic>) {
      final deck = row as Map<String, dynamic>;
      final deckId = deck['id'] as String;
      final path = deck['storage_path'] as String;
      final (fileStatus, fileBody) = await _send(
        'GET',
        _uri('/storage/v1/object/decks/$path'),
      );
      // Строка есть, а файла нет: проверить уникальность нельзя, импорт
      // не продолжаем (безопаснее отказать, чем пропустить коллизию).
      if (fileStatus != 200) _fail('чтение файла $path', fileStatus, fileBody);
      final json = jsonDecode(utf8.decode(fileBody)) as Map<String, dynamic>;
      for (final item in json['items'] as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        owners[map['id'] as String] = deckId;
        for (final q in map['questions'] as List<dynamic>) {
          owners[(q as Map<String, dynamic>)['id'] as String] = deckId;
        }
      }
    }
    return owners;
  }

  @override
  Future<void> upload(String path, List<int> bytes) async {
    final (status, body) = await _send(
      'POST',
      _uri('/storage/v1/object/decks/$path'),
      headers: {
        'Content-Type': 'application/json',
        // Версия строго больше текущей уже проверена; остаток прерванного
        // прошлого импорта (файл есть, строки нет) перезаписываем.
        'x-upsert': 'true',
      },
      body: bytes,
    );
    if (status != 200 && status != 201) _fail('загрузка $path', status, body);
  }

  @override
  Future<void> upsertRow(DeckRow row) async {
    final (status, body) = await _send(
      'POST',
      _uri('/rest/v1/decks', {'on_conflict': 'id'}),
      headers: {
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: utf8.encode(jsonEncode(row.toJson())),
    );
    if (status != 200 && status != 201 && status != 204) {
      _fail('запись decks', status, body);
    }
  }
}
