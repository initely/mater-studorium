/// Максимальная длина имени (знаков Unicode), как в `profiles.display_name`.
const kDisplayNameMaxLength = 64;

/// Запрещённые коды (включительно), как в ограничении сервера
/// `profiles_display_name_clean` (0007_duels.sql): C0 и DEL, C1, U+061C,
/// U+180E, U+200B–200F, U+2028–202E, U+2060–206F, U+FEFF, U+FFF9–FFFB.
/// Это управляющие и «невидимые» символы, в том числе bidi (подмена порядка
/// текста у соперника). Числами, а не литералами, чтобы сам исходник не
/// содержал невидимых символов.
const _forbiddenRanges = <(int, int)>[
  (0x0000, 0x001F),
  (0x007F, 0x009F),
  (0x061C, 0x061C),
  (0x180E, 0x180E),
  (0x200B, 0x200F),
  (0x2028, 0x202E),
  (0x2060, 0x206F),
  (0xFEFF, 0xFEFF),
  (0xFFF9, 0xFFFB),
];

bool _isForbidden(int rune) =>
    _forbiddenRanges.any((r) => rune >= r.$1 && rune <= r.$2);

/// Имя для показа сопернику в виде, который примет сервер: без управляющих и
/// bidi-символов, без пробелов по краям, не длиннее [kDisplayNameMaxLength]
/// знаков. Пустое имя — `null` (имя не задано).
String? sanitizeDisplayName(String input) {
  final cleaned = String.fromCharCodes(
    input.runes.where((r) => !_isForbidden(r)),
  ).trim();
  if (cleaned.isEmpty) return null;
  final runes = cleaned.runes.toList();
  if (runes.length <= kDisplayNameMaxLength) return cleaned;
  return String.fromCharCodes(runes.take(kDisplayNameMaxLength)).trim();
}
