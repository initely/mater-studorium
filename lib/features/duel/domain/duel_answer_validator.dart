import 'dart:convert';

import 'duel_answer.dart';
import 'duel_limits.dart';

final _questionIdPattern = RegExp(r'^[a-z0-9]+([._-][a-z0-9]+)*$');
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
);

/// Предел `duration_ms` на сервере (сутки).
const kDuelMaxDurationMs = 86400000;

/// Размер [value] в байтах так, как его считает сервер: `octet_length(answer::text)`
/// у `jsonb`. Текст `jsonb` ставит пробел после `:` и `,` (`{"a": [1, 2]}`),
/// поэтому он длиннее компактного `jsonEncode`; клиент считает по серверному
/// виду, иначе ответ у границы прошёл бы у клиента и не прошёл у сервера.
int jsonbTextBytes(Object? value) => utf8.encode(_jsonbText(value)).length;

String _jsonbText(Object? v) => switch (v) {
  Map() =>
    '{${[for (final e in v.entries) '${jsonEncode(e.key as String)}: ${_jsonbText(e.value)}'].join(', ')}}',
  List() => '[${[for (final e in v) _jsonbText(e)].join(', ')}]',
  _ => jsonEncode(v),
};

/// Пройдёт ли [p] ограничения сервера (`submit_duel_answer`, CHECK
/// `duel_answers`): неверная запись не отправляется и не блокирует очередь.
bool isValidDuelAnswerPayload(DuelAnswerPayload p) =>
    _uuidPattern.hasMatch(p.duelId) &&
    p.questionId.length <= 128 &&
    _questionIdPattern.hasMatch(p.questionId) &&
    p.durationMs >= 0 &&
    p.durationMs <= kDuelMaxDurationMs &&
    jsonbTextBytes(p.answer) <= kDuelAnswerMaxBytes;
