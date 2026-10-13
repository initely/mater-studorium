import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/duel/domain/display_name.dart';

String _chars(List<int> codes) => String.fromCharCodes(codes);

void main() {
  test('обычное имя остаётся как есть', () {
    expect(sanitizeDisplayName('Саша Петров'), 'Саша Петров');
  });

  test('пробелы по краям убираются, пустое имя — null', () {
    expect(sanitizeDisplayName('  Саша  '), 'Саша');
    expect(sanitizeDisplayName(''), isNull);
    expect(sanitizeDisplayName('   '), isNull);
    expect(sanitizeDisplayName(_chars([0x00A0])), isNull);
  });

  group('запрещённые символы вырезаются (как в ограничении сервера)', () {
    const forbidden = <String, List<int>>{
      'C0 (NUL, табуляция, перевод строки)': [0x00, 0x09, 0x0A, 0x1F],
      'DEL и C1': [0x7F, 0x85, 0x9F],
      'ALM U+061C': [0x061C],
      'U+180E': [0x180E],
      'zero-width и bidi-метки U+200B-200F': [0x200B, 0x200C, 0x200E, 0x200F],
      'разделители строк и bidi-встраивания U+2028-202E': [
        0x2028,
        0x2029,
        0x202A,
        0x202E,
      ],
      'U+2060-206F (в том числе bidi-изоляты)': [
        0x2060,
        0x2066,
        0x2069,
        0x206F,
      ],
      'BOM U+FEFF': [0xFEFF],
      'U+FFF9-FFFB': [0xFFF9, 0xFFFB],
    };
    forbidden.forEach((name, codes) {
      test(name, () {
        for (final code in codes) {
          final input = 'Са${_chars([code])}ша';
          expect(
            sanitizeDisplayName(input),
            'Саша',
            reason: 'U+${code.toRadixString(16)}',
          );
        }
      });
    });

    test('имя только из запрещённых символов — null', () {
      expect(sanitizeDisplayName(_chars([0x200B, 0x202E, 0x0A])), isNull);
    });
  });

  test('длина ограничена 64 знаками Unicode, а не единицами UTF-16', () {
    expect(sanitizeDisplayName('я' * 64), 'я' * 64);
    expect(sanitizeDisplayName('я' * 100), 'я' * 64);
    // Эмодзи — один знак, две единицы UTF-16: пара не рвётся.
    final emoji = '😀' * 70;
    final cut = sanitizeDisplayName(emoji)!;
    expect(cut.runes.length, 64);
    expect(cut, '😀' * 64);
  });

  test('обрезка по длине не оставляет пробел на конце', () {
    final input = '${'я' * 63} ${'ю' * 10}';
    expect(sanitizeDisplayName(input), 'я' * 63);
  });
}
