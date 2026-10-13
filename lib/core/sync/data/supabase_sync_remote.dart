import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/catalog/domain/question_type.dart';
import '../../../features/duel/domain/duel_answer.dart';
import '../../../features/reports/domain/report.dart';
import '../../../features/session/domain/grade_source.dart';
import '../../../features/session/domain/review_log.dart';
import '../../../features/srs/domain/item_state.dart';
import '../../../features/srs/domain/rating.dart';
import '../../../features/srs/domain/srs_state.dart';
import '../../errors/app_error.dart';
import '../domain/sync_remote.dart';

const _stateColumns =
    'item_id,deck_id,due,stability,difficulty,elapsed_days,scheduled_days,'
    'reps,lapses,state,last_review,last_question_id,updated_at,sync_seq,'
    'user_id';
const _logColumns =
    'id,deck_id,deck_version,item_id,question_id,question_type,rating,'
    'grade_source,llm_score,answer_text,duration_ms,reviewed_at,sync_seq,'
    'user_id';

/// [SyncRemote] поверх Supabase (`0003_sync.sql`): запись через RPC
/// `insert_review_logs` и `upsert_item_states`, чтение — SELECT с RLS.
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote(
    this._client, {
    this.timeout = const Duration(seconds: 30),
  });

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<int> insertReviewLogs(String userId, List<ReviewLog> logs) =>
      _guard(userId, () async {
        final inserted = await _client.rpc<dynamic>(
          'insert_review_logs',
          params: {
            'p_user_id': userId,
            'p_logs': [for (final l in logs) logToJson(l)],
          },
        );
        return (inserted as num).toInt();
      });

  @override
  Future<List<ItemState>> upsertItemStates(
    String userId,
    List<ItemState> states,
  ) => _guard(userId, () async {
    final rows = await _client.rpc<dynamic>(
      'upsert_item_states',
      params: {
        'p_user_id': userId,
        'p_states': [for (final s in states) stateToJson(s)],
      },
    );
    return [
      for (final row in rows as List<dynamic>)
        _ownState(userId, row as Map<String, dynamic>),
    ];
  });

  // postgrest-dart сортирует по убыванию, если не сказать иначе: страница
  // тогда начиналась бы с конца, и курсор перепрыгнул бы остальное
  // (поймано live-тестом). Поэтому `ascending: true` явно.
  @override
  Future<PulledPage<ItemState>> pullItemStates(
    String userId, {
    required int afterSeq,
    required int limit,
  }) => _guard(userId, () async {
    final rows = await _client
        .from('user_item_state')
        .select(_stateColumns)
        .eq('user_id', userId)
        .gt('sync_seq', afterSeq)
        .order('sync_seq', ascending: true)
        .limit(limit);
    return _page(rows, (row) {
      _checkOwner(userId, row);
      // Строка, которую клиент не разбирает (например, время, которое сервер
      // принял до появления ограничений), пропускается: курсор её проходит,
      // иначе pull встал бы на ней навсегда.
      try {
        return stateFromJson(row);
      } on UnexpectedError {
        return null;
      }
    });
  });

  @override
  Future<PulledPage<ReviewLog>> pullReviewLogs(
    String userId, {
    required int afterSeq,
    required int limit,
  }) => _guard(userId, () async {
    final rows = await _client
        .from('review_logs')
        .select(_logColumns)
        .eq('user_id', userId)
        .gt('sync_seq', afterSeq)
        .order('sync_seq', ascending: true)
        .limit(limit);
    return _page(rows, (row) {
      _checkOwner(userId, row);
      // Лог, который этот клиент не понимает (новый формат вопроса с более
      // нового клиента), пропускается: курсор его проходит.
      try {
        return logFromJson(row);
      } on Object {
        return null;
      }
    });
  });

  @override
  Future<bool> submitReport(String userId, Report report) =>
      _guard(userId, () async {
        final created = await _client.rpc<dynamic>(
          'submit_report',
          params: {'p_user_id': userId, 'p_report': report.toJson()},
        );
        if (created is! bool) {
          throw const UnexpectedError('submit_report: ответ не bool');
        }
        return created;
      });

  @override
  Future<bool> submitDuelAnswer(String userId, DuelAnswerPayload answer) =>
      _guard(userId, () async {
        final json = await _client.rpc<dynamic>(
          'submit_duel_answer',
          params: {
            'p_user_id': userId,
            'p_duel_id': answer.duelId,
            'p_question_id': answer.questionId,
            'p_answer': answer.answer,
            'p_is_correct': answer.isCorrect,
            'p_duration_ms': answer.durationMs,
          },
        );
        if (json is! Map<String, dynamic>) {
          throw const UnexpectedError('submit_duel_answer: ответ не объект');
        }
        return switch (json['result']) {
          'recorded' => true,
          'duplicate' => false,
          final other => throw UnexpectedError(
            'submit_duel_answer: result $other',
          ),
        };
      });

  @override
  Future<Set<String>> pullHiddenQuestions(String userId) =>
      _guard(userId, () async {
        final rows = await _client.rpc<dynamic>('hidden_questions');
        if (rows is! List) {
          throw const UnexpectedError('hidden_questions: ответ не массив');
        }
        // Не строка — мусор: пропускается (лучше показать вопрос, чем
        // потерять весь список).
        return {
          for (final id in rows)
            if (id is String && id.isNotEmpty) id,
        };
      });

  PulledPage<T> _page<T>(
    List<Map<String, dynamic>> rows,
    T? Function(Map<String, dynamic> row) parse,
  ) {
    final parsed = <T>[];
    int? lastSeq;
    for (final row in rows) {
      final seq = (row['sync_seq'] as num).toInt();
      if (lastSeq == null || seq > lastSeq) lastSeq = seq;
      final value = parse(row);
      if (value != null) parsed.add(value);
    }
    return PulledPage(rows: parsed, fetched: rows.length, lastSeq: lastSeq);
  }

  /// Сервер отдаёт только строки сессии (RLS) и только [userId] (фильтр);
  /// строка другого пользователя — признак, что сессия сменилась: прерываем.
  static void _checkOwner(String userId, Map<String, dynamic> row) {
    if (row['user_id'] != userId) {
      throw const AuthError('сервер вернул строку другого пользователя');
    }
  }

  static ItemState _ownState(String userId, Map<String, dynamic> row) {
    _checkOwner(userId, row);
    return stateFromJson(row);
  }

  Future<T> _guard<T>(String userId, Future<T> Function() action) async {
    // Запрос уйдёт с JWT текущей сессии; если это уже не [userId], данные
    // попали бы не тому пользователю (сервер это тоже проверяет: p_user_id).
    final current = _client.auth.currentUser?.id;
    if (current == null) {
      throw const AuthError('нет сессии');
    }
    if (current != userId) {
      throw const AuthError('сессия другого пользователя');
    }
    try {
      return await action().timeout(timeout);
    } on AppError {
      rethrow;
    } catch (e) {
      throw mapSyncRemoteError(e);
    }
  }
}

/// Сбой Supabase, http или таймаут → [AppError]. Сырые исключения наружу не
/// выходят.
AppError mapSyncRemoteError(Object e) {
  switch (e) {
    case AppError():
      return e;
    case TimeoutException():
    case http.ClientException():
      return NetworkError('Сервер недоступен', cause: e);
    case PostgrestException(:final code, :final message):
      final status = code != null && RegExp(r'^[1-5]\d\d$').hasMatch(code)
          ? int.parse(code)
          : null;
      // MS429 — дневной лимит жалоб (`submit_report`, 0005_reports.sql):
      // не сеть (иначе один исчерпанный лимит останавливал бы весь синк) и
      // не отказ пакета; повторить можно после полуночи UTC.
      if (code == 'MS429') {
        return QuotaExceededError(
          'Лимит жалоб на сегодня исчерпан: $message',
          cause: e,
        );
      }
      // MS410 — срок дуэли вышел или она закрыта, MS404 — дуэли нет у этого
      // пользователя (`submit_duel_answer`, 0008_duel_play.sql): повтор не
      // поможет, запись из outbox отбрасывается.
      if (code == 'MS410' || code == 'MS404') {
        return DuelClosedError('Дуэль закрыта для ответов ($code)', cause: e);
      }
      // 55P03 — lock_timeout в RPC (запись того же пользователя ждала
      // блокировку дольше 3 с): временное, повтор с паузой.
      if ((status != null && (status >= 500 || status == 429)) ||
          code == '55P03') {
        return NetworkError('Сервер вернул $code: $message', cause: e);
      }
      if (status == 401 ||
          status == 403 ||
          code == '42501' ||
          (code?.startsWith('PGRST3') ?? false)) {
        return AuthError('Доступ запрещён ($code): $message', cause: e);
      }
      // 22xxx — неверное значение (22P05 — `\u0000` в тексте), 23xxx —
      // нарушение ограничения, 54000 — превышен размер пакета
      // (0003_sync.sql), PGRST1xx и HTTP 400/413 — PostgREST не принял тело
      // запроса (PGRST102 — невалидный JSON/UTF-8). Повтор того же пакета не
      // поможет; сервис отправит строки по одной.
      if (code != null &&
          (code.startsWith('22') ||
              code.startsWith('23') ||
              code == '54000' ||
              code.startsWith('PGRST1') ||
              status == 400 ||
              status == 413)) {
        return SyncRejectedError(
          'Сервер отклонил пакет ($code): $message',
          cause: e,
        );
      }
      return UnexpectedError('Синхронизация ($code): $message', cause: e);
    default:
      return UnexpectedError('Синхронизация: неожиданная ошибка', cause: e);
  }
}

String _ts(DateTime t) => t.toUtc().toIso8601String();

DateTime _parseTs(Object? v) => DateTime.parse(v! as String).toUtc();

/// Поля `upsert_item_states` (без `user_id`: сервер берёт `auth.uid()`).
Map<String, Object?> stateToJson(ItemState s) => {
  'item_id': s.itemId,
  'deck_id': s.deckId,
  'due': _ts(s.due),
  'stability': s.stability,
  'difficulty': s.difficulty,
  'elapsed_days': s.elapsedDays,
  'scheduled_days': s.scheduledDays,
  'reps': s.reps,
  'lapses': s.lapses,
  'state': s.state.code,
  'last_review': s.lastReview == null ? null : _ts(s.lastReview!),
  'last_question_id': s.lastQuestionId,
  'updated_at': _ts(s.updatedAt),
};

ItemState stateFromJson(Map<String, dynamic> row) {
  try {
    return ItemState(
      itemId: row['item_id'] as String,
      deckId: row['deck_id'] as String,
      due: _parseTs(row['due']),
      stability: (row['stability'] as num).toDouble(),
      difficulty: (row['difficulty'] as num).toDouble(),
      elapsedDays: (row['elapsed_days'] as num).toInt(),
      scheduledDays: (row['scheduled_days'] as num).toInt(),
      reps: (row['reps'] as num).toInt(),
      lapses: (row['lapses'] as num).toInt(),
      state: SrsState.fromCode((row['state'] as num).toInt()),
      lastReview: row['last_review'] == null
          ? null
          : _parseTs(row['last_review']),
      lastQuestionId: row['last_question_id'] as String?,
      updatedAt: _parseTs(row['updated_at']),
    );
  } on Object catch (e) {
    throw UnexpectedError('Строка user_item_state неожиданной формы', cause: e);
  }
}

/// Поля `insert_review_logs` (без `user_id`).
Map<String, Object?> logToJson(ReviewLog l) => {
  'id': l.id,
  'deck_id': l.deckId,
  'deck_version': l.deckVersion,
  'item_id': l.itemId,
  'question_id': l.questionId,
  'question_type': l.questionType.wire,
  'rating': l.rating.code,
  'grade_source': l.gradeSource.wire,
  'llm_score': l.llmScore,
  'answer_text': l.answerText,
  'duration_ms': l.durationMs,
  'reviewed_at': _ts(l.reviewedAt),
};

ReviewLog logFromJson(Map<String, dynamic> row) => ReviewLog(
  id: row['id'] as String,
  deckId: row['deck_id'] as String,
  deckVersion: (row['deck_version'] as num).toInt(),
  itemId: row['item_id'] as String,
  questionId: row['question_id'] as String,
  questionType: QuestionType.fromWire(row['question_type'] as String),
  rating: Rating.fromCode((row['rating'] as num).toInt()),
  gradeSource: GradeSource.fromWire(row['grade_source'] as String),
  llmScore: (row['llm_score'] as num?)?.toDouble(),
  answerText: row['answer_text'] as String?,
  durationMs: (row['duration_ms'] as num).toInt(),
  reviewedAt: _parseTs(row['reviewed_at']),
);
