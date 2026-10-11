import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../domain/remote_deck.dart';
import 'deck_remote_source.dart';

/// Имя bucket в Storage (миграция 0002_decks.sql).
const decksBucket = 'decks';

const _columns = 'id,title,topic,lang,version,item_count,storage_path';

/// [DeckRemoteSource] поверх Supabase: PostgREST для списка, Storage для файла.
/// Читает с правами пользователя (JWT), RLS отдаёт только доступные колоды.
class SupabaseDeckRemoteSource implements DeckRemoteSource {
  SupabaseDeckRemoteSource(
    this._client, {
    this.timeout = const Duration(seconds: 30),
    bool Function()? hasSession,
  }) : _hasSession = hasSession ?? (() => _client.auth.currentSession != null);

  final SupabaseClient _client;
  final Duration timeout;
  final bool Function() _hasSession;

  @override
  Future<List<RemoteDeck>> fetchDecks() => _guard(() async {
    final rows = await _client.from('decks').select(_columns).order('title');
    return [for (final row in rows) _fromRow(row)];
  });

  @override
  Future<RemoteDeck?> fetchDeck(String deckId) => _guard(() async {
    final row = await _client
        .from('decks')
        .select(_columns)
        .eq('id', deckId)
        .maybeSingle();
    return row == null ? null : _fromRow(row);
  });

  @override
  Future<Uint8List> downloadDeckFile(String storagePath) =>
      _guard(() => _client.storage.from(decksBucket).download(storagePath));

  Future<T> _guard<T>(Future<T> Function() action) async {
    // Без сессии запрос ушёл бы с anon-ключом и получил бы отказ RLS. Вход
    // откладывается до появления сети (AC1.1), поэтому это «нужна сеть».
    if (!_hasSession()) {
      throw const NetworkError('Нет сессии: анонимный вход ещё не выполнен');
    }
    try {
      return await action().timeout(timeout);
    } on AppError {
      rethrow;
    } catch (e) {
      throw mapRemoteError(e);
    }
  }

  RemoteDeck _fromRow(Map<String, dynamic> row) {
    try {
      return RemoteDeck(
        id: row['id'] as String,
        title: row['title'] as String,
        topic: row['topic'] as String,
        lang: row['lang'] as String,
        version: row['version'] as int,
        itemCount: row['item_count'] as int,
        storagePath: row['storage_path'] as String,
      );
    } on TypeError catch (e) {
      throw UnexpectedError('Строка decks неожиданной формы: $row', cause: e);
    }
  }
}

/// Превращает сбой Supabase, http или таймаут в [AppError]: сырые исключения
/// наружу (в UI) не выходят.
AppError mapRemoteError(Object e) {
  switch (e) {
    case AppError():
      return e;
    case TimeoutException():
    case http.ClientException():
      return NetworkError('Сервер недоступен', cause: e);
    case PostgrestException(:final code, :final message):
      return _mapStatus(code, message, e);
    case StorageException(:final statusCode, :final message):
      // Storage на отсутствующий объект отвечает HTTP 400, а 404 лежит в теле
      // (`{"statusCode":"404","error":"not_found",...}`), которое клиент
      // отдаёт в message как есть.
      if (statusCode == '404' ||
          message.contains('not_found') ||
          message.contains('Object not found')) {
        return DeckNotFoundError(message);
      }
      return _mapStatus(statusCode, message, e);
    default:
      return UnexpectedError('Каталог: неожиданная ошибка', cause: e);
  }
}

/// [code] у PostgREST — SQLSTATE (`42501`), код PostgREST (`PGRST301`) или,
/// если в теле нет кода, HTTP-статус из трёх цифр.
AppError _mapStatus(String? code, String message, Object cause) {
  final status = code != null && RegExp(r'^[1-5]\d\d$').hasMatch(code)
      ? int.parse(code)
      : null;
  if (status != null && status >= 500) {
    return NetworkError('Сервер вернул $status: $message', cause: cause);
  }
  if (status == 401 ||
      status == 403 ||
      code == '42501' ||
      (code?.startsWith('PGRST3') ?? false)) {
    return AuthError('Доступ запрещён ($code): $message', cause: cause);
  }
  return UnexpectedError('Каталог ($code): $message', cause: cause);
}
