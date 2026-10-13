/// Максимальная длина имени (знаков Unicode), как в `profiles.display_name`.
const kDisplayNameMaxLength = 64;

/// Запрещённые коды (включительно), как в `private.display_name_clean`
/// (0007_duels.sql, ревью T22 S4): C0, DEL и C1; U+00AD; U+034F; U+0600–0605,
/// U+061C, U+06DD, U+070F, U+0890–0891, U+08E2; U+115F, U+1160, U+3164, U+FFA0
/// (Hangul filler); U+1680; U+17B4–17B5; U+180B–180F; U+2000–200F (пробелы,
/// zero-width, ZWJ, ZWNJ, bidi-метки); U+2028–202F; U+205F–206F (включая
/// bidi-изоляты); U+2800; U+FE00–FE0F; U+FEFF; U+FFF0–FFFC; U+110BD, U+110CD,
/// U+13430–1343F, U+1BCA0–1BCA3, U+1D173–1D17A; теги U+E0000–E0FFF. Это
/// невидимые и управляющие символы, в том числе bidi (подмена порядка текста
/// у соперника). Числами, а не литералами, чтобы сам исходник не содержал
/// невидимых символов.
///
/// Цена: составные эмодзи (ZWJ) и эмодзи-представление U+FE0F вырезаются,
/// сердечко с U+FE0F сохранится без него (решение ADR-35: проще и безопаснее,
/// чем разбирать допустимые последовательности).
const _forbiddenRanges = <(int, int)>[
  (0x0000, 0x001F),
  (0x007F, 0x009F),
  (0x00AD, 0x00AD),
  (0x034F, 0x034F),
  (0x0600, 0x0605),
  (0x061C, 0x061C),
  (0x06DD, 0x06DD),
  (0x070F, 0x070F),
  (0x0890, 0x0891),
  (0x08E2, 0x08E2),
  (0x115F, 0x1160),
  (0x1680, 0x1680),
  (0x17B4, 0x17B5),
  (0x180B, 0x180F),
  (0x2000, 0x200F),
  (0x2028, 0x202F),
  (0x205F, 0x206F),
  (0x2800, 0x2800),
  (0x3164, 0x3164),
  (0xFE00, 0xFE0F),
  (0xFEFF, 0xFEFF),
  (0xFFA0, 0xFFA0),
  (0xFFF0, 0xFFFC),
  (0x110BD, 0x110BD),
  (0x110CD, 0x110CD),
  (0x13430, 0x1343F),
  (0x1BCA0, 0x1BCA3),
  (0x1D173, 0x1D17A),
  (0xE0000, 0xE0FFF),
];

/// Комбинирующие знаки: сервер отвергает три и больше подряд (zalgo), клиент
/// оставляет не больше двух подряд.
const _combiningRanges = <(int, int)>[
  (0x0300, 0x036F),
  (0x0483, 0x0489),
  (0x1AB0, 0x1AFF),
  (0x1DC0, 0x1DFF),
  (0x20D0, 0x20FF),
  (0xFE20, 0xFE2F),
];

const _maxCombiningRun = 2;

bool _inRanges(List<(int, int)> ranges, int rune) =>
    ranges.any((r) => rune >= r.$1 && rune <= r.$2);

/// Имя для показа сопернику в виде, который примет сервер: без управляющих,
/// bidi и «невидимых» символов, без длинных цепочек комбинирующих знаков, без
/// пробелов по краям, не длиннее [kDisplayNameMaxLength] знаков. Пустое имя —
/// `null` (имя не задано).
String? sanitizeDisplayName(String input) {
  final kept = <int>[];
  var combiningRun = 0;
  for (final rune in input.runes) {
    if (_inRanges(_forbiddenRanges, rune)) continue;
    if (_inRanges(_combiningRanges, rune)) {
      combiningRun++;
      if (combiningRun > _maxCombiningRun) continue;
    } else {
      combiningRun = 0;
    }
    kept.add(rune);
  }
  final cleaned = String.fromCharCodes(kept).trim();
  if (cleaned.isEmpty) return null;
  final runes = cleaned.runes.toList();
  if (runes.length <= kDisplayNameMaxLength) return cleaned;
  return String.fromCharCodes(runes.take(kDisplayNameMaxLength)).trim();
}
