import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../domain/grading_repository.dart';
import '../domain/open_answer_limits.dart';
import '../domain/open_grade.dart';
import '../domain/open_grade_parser.dart';

/// Имя Edge Function (`supabase/functions/grade-open-answer`).
const String kGradeFunctionName = 'grade-open-answer';

/// Таймаут клиента (ТЗ M5, AC5.1: 15 с). Сервер сам укладывает модель в 12 с
/// (`GRADING_MODEL_DEADLINE_MS`, ADR-31, п. 5) и отвечает 504 `model_timeout`;
/// 3 с запаса на Auth, чтение колоды и сеть, чтобы клиент обычно получал
/// осмысленный 504, а не обрывал запрос первым.
const Duration kGradingClientTimeout = Duration(seconds: 15);

/// [GradingRepository] поверх `supabase.functions.invoke('grade-open-answer')`.
///
/// Тело запроса строго по контракту (`contract.ts`): `deck_id`,
/// `deck_version`, `question_id`, `answer_text`, `input_mode`. Любое другое
/// поле сервер отклонил бы (`400 unknown_field`), а рубрика и эталон с клиента
/// недопустимы по смыслу (ADR-31, п. 1).
class SupabaseGradingRepository implements GradingRepository {
  SupabaseGradingRepository(
    this._client, {
    this.timeout = kGradingClientTimeout,
  });

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<OpenGrade> grade(GradeRequest request) async {
    if (request.answerText.length > kMaxOpenAnswerChars) {
      // Поле ввода такого не пропускает; без запроса и без сети.
      throw const RequestRejectedError(
        'ответ длиннее лимита',
        code: 'answer_too_long',
      );
    }
    if (_client.auth.currentSession == null) {
      throw const AuthError('нет сессии пользователя');
    }
    final abort = Completer<void>();
    try {
      final response = await _client.functions
          .invoke(
            kGradeFunctionName,
            body: gradeRequestBody(request),
            abortSignal: abort.future,
          )
          .timeout(
            timeout,
            onTimeout: () {
              // Оборвать запрос в полёте, а не бросить его висеть.
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('grade-open-answer', timeout);
            },
          );
      try {
        return parseOpenGrade(response.data);
      } on OpenGradeFormatException catch (e) {
        throw UnexpectedError('ответ оценки не по контракту: ${e.message}');
      }
    } on AppError {
      rethrow;
    } on Object catch (e) {
      throw mapGradingError(e);
    }
  }
}

/// Тело запроса: ровно поля контракта, ничего лишнего.
Map<String, Object> gradeRequestBody(GradeRequest r) => {
  'deck_id': r.deckId,
  'deck_version': r.deckVersion,
  'question_id': r.questionId,
  'answer_text': r.answerText,
  'input_mode': r.inputMode.wire,
};

/// Сбой вызова функции → [AppError]; сырые исключения Supabase и http наружу
/// не выходят.
///
/// Решает **статус**, тело разбирается только ради `reset_at` у 429 и кода
/// 4xx: шлюз Supabase отвечает на плохой JWT своим телом
/// (`{"code": "UNAUTHORIZED_…"}`, README функции), поэтому любой 401 —
/// «не вошёл» без разбора тела.
AppError mapGradingError(Object e) {
  switch (e) {
    case AppError():
      return e;
    case TimeoutException():
    case http.ClientException():
      return NetworkError('Сервер оценки недоступен', cause: e);
    case FunctionException(:final status, :final details):
      return _fromStatus(status, details, e);
    default:
      return UnexpectedError('Оценка ответа: неожиданная ошибка', cause: e);
  }
}

AppError _fromStatus(int status, Object? details, Object cause) {
  if (status == 401) return AuthError('Не выполнен вход (401)', cause: cause);
  if (status == 429) {
    final reset = _errorField(details, 'reset_at');
    return QuotaExceededError(
      'Лимит оценок исчерпан (429)',
      resetAt: reset is String ? DateTime.tryParse(reset)?.toUtc() : null,
      cause: cause,
    );
  }
  // 0 — запрос не дошёл (сеть); 408 и 5xx (в том числе 502 model_error,
  // 504 model_timeout и 503) — сервер временно не может.
  if (status <= 0 || status == 408 || status >= 500) {
    return NetworkError('Сервер оценки недоступен ($status)', cause: cause);
  }
  if (status >= 400) {
    final code = _errorField(details, 'code');
    return RequestRejectedError(
      'Сервер отклонил запрос оценки ($status)',
      status: status,
      code: code is String ? code : null,
    );
  }
  return UnexpectedError('Оценка ответа: статус $status', cause: cause);
}

/// `error.<name>` из тела ошибки `{"error": {...}}`; мусор — `null`.
Object? _errorField(Object? details, String name) {
  try {
    var body = details;
    if (body is String) body = jsonDecode(body);
    if (body is Map && body['error'] is Map) {
      return (body['error'] as Map)[name];
    }
  } on FormatException {
    // Тело не JSON (например, страница шлюза): подробностей нет.
  }
  return null;
}
