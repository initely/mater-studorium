import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/sync/data/supabase_sync_remote.dart'
    show mapSyncRemoteError;
import '../domain/duel.dart';
import '../domain/duel_repository.dart';
import '../domain/duel_status.dart';

/// [DuelRepository] поверх Supabase RPC (`0007_duels.sql`): запись только через
/// `create_duel` и `join_duel`, чтение через `get_duel` и `my_duels` (они
/// отдают и имя соперника, которое прямым SELECT не прочитать). Сырые
/// исключения наружу не выходят.
class SupabaseDuelRepository implements DuelRepository {
  SupabaseDuelRepository(
    this._client, {
    this.timeout = const Duration(seconds: 30),
  });

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<Duel> create({
    required String duelId,
    required String deckId,
    required int deckVersion,
    required List<String> questionIds,
  }) => _guard((userId) async {
    try {
      final json = await _client.rpc<dynamic>(
        'create_duel',
        params: {
          'p_user_id': userId,
          'p_duel_id': duelId,
          'p_deck_id': deckId,
          'p_deck_version': deckVersion,
          'p_question_ids': questionIds,
        },
      );
      return duelFromJson(json);
    } on PostgrestException catch (e) {
      // 23503: колоды нет, она не публичная или версия выше серверной.
      if (e.code == '23503') throw DeckNotFoundError(deckId);
      rethrow;
    }
  });

  @override
  Future<Duel> join(String code) => _guard((userId) async {
    final json = await _client.rpc<dynamic>(
      'join_duel',
      params: {'p_user_id': userId, 'p_code': code},
    );
    if (json is! Map<String, dynamic>) {
      throw const UnexpectedError('join_duel: ответ не объект');
    }
    switch (json['result']) {
      case 'joined' || 'own_duel':
        return duelFromJson(json['duel']);
      case 'not_found':
        throw const DuelCodeNotFoundError();
      case 'full':
        throw const DuelFullError();
      default:
        throw UnexpectedError('join_duel: result ${json['result']}');
    }
  });

  @override
  Future<Duel?> get(String duelId) => _guard((userId) async {
    final json = await _client.rpc<dynamic>(
      'get_duel',
      params: {'p_duel_id': duelId},
    );
    return json == null ? null : duelFromJson(json);
  });

  @override
  Future<List<Duel>> mine() => _guard((userId) async {
    final json = await _client.rpc<dynamic>('my_duels');
    if (json is! List) {
      throw const UnexpectedError('my_duels: ответ не массив');
    }
    return [for (final row in json) duelFromJson(row)];
  });

  @override
  Future<String?> displayName() => _guard((userId) async {
    final row = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', userId)
        .maybeSingle();
    return row?['display_name'] as String?;
  });

  @override
  Future<void> setDisplayName(String? name) => _guard((userId) async {
    await _client
        .from('profiles')
        .update({'display_name': name})
        .eq('id', userId);
  });

  Future<T> _guard<T>(Future<T> Function(String userId) action) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthError('нет сессии');
    try {
      return await action(userId).timeout(timeout);
    } on AppError {
      rethrow;
    } catch (e) {
      throw mapDuelError(e);
    }
  }
}

/// Сбой Supabase, http или таймаут → [AppError]. Лимиты дуэли (`MS429` с
/// `hint`) → [DuelLimitError]; остальное — как у синхронизации, но ошибки
/// значений (22xxx, 23xxx) — [RequestRejectedError].
AppError mapDuelError(Object e) {
  switch (e) {
    case AppError():
      return e;
    case TimeoutException():
    case http.ClientException():
      return NetworkError('Сервер недоступен', cause: e);
    case PostgrestException(:final code, :final hint, :final message):
      if (code == 'MS429') {
        return DuelLimitError(switch (hint) {
          'active_limit' => DuelLimitKind.activeDuels,
          'daily_limit' => DuelLimitKind.dailyCreate,
          'join_attempts' => DuelLimitKind.joinAttempts,
          // Незнакомый hint: самый безобидный текст («подождите»).
          _ => DuelLimitKind.activeDuels,
        }, cause: e);
      }
      // MS503: не нашёлся свободный код (практически недостижимо), повтор
      // поможет.
      if (code == 'MS503') {
        return NetworkError('Сервер не смог создать код: $message', cause: e);
      }
      if (code != null && (code.startsWith('22') || code.startsWith('23'))) {
        return RequestRejectedError(
          'Сервер отклонил запрос ($code): $message',
          code: code,
        );
      }
      return mapSyncRemoteError(e);
    default:
      return UnexpectedError('Дуэль: неожиданная ошибка', cause: e);
  }
}

/// Разбор объекта дуэли из ответа RPC. Неожиданная форма — [UnexpectedError].
Duel duelFromJson(Object? json) {
  try {
    final row = json! as Map<String, dynamic>;
    DateTime time(Object? v) => DateTime.parse(v! as String).toUtc();
    DateTime? timeOrNull(Object? v) => v == null ? null : time(v);
    return Duel(
      id: row['id']! as String,
      code: row['code'] as String?,
      deckId: row['deck_id']! as String,
      deckVersion: (row['deck_version']! as num).toInt(),
      questionIds: [for (final q in row['question_ids']! as List) q as String],
      status: DuelStatus.fromWire(row['status']! as String),
      createdAt: time(row['created_at']),
      expiresAt: time(row['expires_at']),
      isCreator: row['is_creator']! as bool,
      otherJoined: row['other_joined']! as bool,
      otherName: row['other_name'] as String?,
      myDoneAt: timeOrNull(row['my_done_at']),
      otherDoneAt: timeOrNull(row['other_done_at']),
    );
  } on Object catch (e) {
    throw UnexpectedError('Дуэль неожиданной формы', cause: e);
  }
}
