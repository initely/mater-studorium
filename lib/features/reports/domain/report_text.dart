import 'dart:convert';

/// Наибольшие длины текстов в жалобе. Совпадают с ограничениями таблицы
/// `reports` (`0005_reports.sql`): сервер отклоняет длиннее, поэтому клиент
/// обрезает заранее (иначе одна длинная жалоба навсегда застряла бы в
/// очереди, урок T17). Длины в единицах UTF-16; сервер считает символы
/// Unicode, то есть принимает не меньше.
const kMaxReportCommentChars = 500;
const kMaxReportQuestionTextChars = 600;
const kMaxReportAnswerChars = 2000;

final _controlChars = RegExp(
  '[\\u0000-\\u0008\\u000b\\u000c\\u000e-\\u001f\\u007f]',
);

/// Текст, который примут JSON и `text` в Postgres. Порядок: вырезать `\u0000`
/// и прочие управляющие символы (иначе `22P05`; сервер вырезает их сам, но
/// клиенту не нужно на это рассчитывать), заменить непарные суррогаты на
/// U+FFFD (иначе невалидный UTF-8 и PostgREST `PGRST102`, как в
/// `sanitizeAnswerText`), обрезать по краям и до [max] без разрыва
/// суррогатной пары. Пустой результат — `null`.
String? sanitizeReportText(String? text, {required int max}) {
  if (text == null) return null;
  final cleaned = utf8
      .decode(utf8.encode(text.replaceAll(_controlChars, '')))
      .trim();
  if (cleaned.isEmpty) return null;
  if (cleaned.length <= max) return cleaned;
  var end = max;
  final last = cleaned.codeUnitAt(end - 1);
  // Верхняя половина пары на границе: пара целиком не помещается.
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  final cut = cleaned.substring(0, end).trimRight();
  return cut.isEmpty ? null : cut;
}
