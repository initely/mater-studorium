/// Алфавит кода приглашения: без неоднозначных знаков (нет I, L, O, 0, 1);
/// тот же, что у сервера (`private.new_duel_code`, 0007_duels.sql).
const kDuelCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Длина кода.
const kDuelCodeLength = 6;

final _codePattern = RegExp('^[$kDuelCodeAlphabet]{$kDuelCodeLength}\$');

/// Приводит введённое пользователем к коду: убирает пробелы (код читают вслух
/// и диктуют группами), переводит в верхний регистр. Возвращает `null`, если
/// это не код допустимого вида (сервер такой код всё равно не найдёт, лишний
/// запрос не нужен).
String? normalizeDuelCode(String input) {
  final code = input.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return _codePattern.hasMatch(code) ? code : null;
}

/// Код для показа: `K7Q 2MX` (группы по три читаются проще).
String formatDuelCode(String code) => code.length == kDuelCodeLength
    ? '${code.substring(0, 3)} ${code.substring(3)}'
    : code;
