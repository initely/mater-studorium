/// Алфавит кода приглашения: без неоднозначных знаков (нет I, L, O, 0, 1);
/// тот же, что у сервера (`private.new_duel_code`, 0007_duels.sql).
const kDuelCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Длина кода.
const kDuelCodeLength = 6;

final _codePattern = RegExp('^[$kDuelCodeAlphabet]{$kDuelCodeLength}\$');

/// Кириллические буквы, неотличимые на глаз от латинских букв алфавита кода
/// (на русской раскладке «К7Q 2МХ» набирается с кириллическими К, М, Х).
/// Заглавные и строчные; коды символов, а не литералы, чтобы в исходнике не
/// путать их с латиницей.
const _homoglyphs = <int, String>{
  0x0410: 'A', 0x0430: 'A', // А а
  0x0412: 'B', 0x0432: 'B', // В в
  0x0415: 'E', 0x0435: 'E', // Е е
  0x041A: 'K', 0x043A: 'K', // К к
  0x041C: 'M', 0x043C: 'M', // М м
  0x041D: 'H', 0x043D: 'H', // Н н
  0x0420: 'P', 0x0440: 'P', // Р р
  0x0421: 'C', 0x0441: 'C', // С с
  0x0422: 'T', 0x0442: 'T', // Т т
  0x0425: 'X', 0x0445: 'X', // Х х
};

/// Приводит введённое пользователем к коду: убирает пробелы (код читают вслух
/// и диктуют группами), заменяет похожие кириллические буквы латинскими,
/// переводит в верхний регистр. Возвращает `null`, если это не код допустимого
/// вида (сервер такой код всё равно не найдёт, лишний запрос не нужен).
String? normalizeDuelCode(String input) {
  final compact = input.replaceAll(RegExp(r'\s+'), '');
  final mapped = String.fromCharCodes(
    compact.runes.expand((r) => _homoglyphs[r]?.codeUnits ?? [r]),
  ).toUpperCase();
  return _codePattern.hasMatch(mapped) ? mapped : null;
}

/// Код для показа: `K7Q 2MX` (группы по три читаются проще).
String formatDuelCode(String code) => code.length == kDuelCodeLength
    ? '${code.substring(0, 3)} ${code.substring(3)}'
    : code;
