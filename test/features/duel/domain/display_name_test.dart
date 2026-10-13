import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/duel/domain/display_name.dart';

String _chars(List<int> codes) => String.fromCharCodes(codes);

/// Начало и конец каждого запрещённого диапазона сервера
/// (`private.display_name_clean`, 0007_duels.sql): тест падает, если клиент
/// «забыл» диапазон.
const _forbidden = <String, List<int>>{
  'C0 (NUL, табуляция, перевод строки, US)': [0x00, 0x09, 0x0A, 0x1F],
  'DEL и C1': [0x7F, 0x85, 0x9F],
  'мягкий перенос U+00AD': [0x00AD],
  'CGJ U+034F': [0x034F],
  'арабские форматирующие U+0600-0605': [0x0600, 0x0605],
  'ALM U+061C': [0x061C],
  'U+06DD, U+070F, U+0890, U+0891, U+08E2': [
    0x06DD,
    0x070F,
    0x0890,
    0x0891,
    0x08E2,
  ],
  'Hangul filler U+115F, U+1160, U+3164, U+FFA0': [
    0x115F,
    0x1160,
    0x3164,
    0xFFA0,
  ],
  'U+1680 (Ogham)': [0x1680],
  'khmer U+17B4-17B5': [0x17B4, 0x17B5],
  'mongolian U+180B-180F': [0x180B, 0x180E, 0x180F],
  'пробелы и zero-width U+2000-200F (ZWJ, ZWNJ, bidi-метки)': [
    0x2000,
    0x2007,
    0x200A,
    0x200B,
    0x200C,
    0x200D,
    0x200E,
    0x200F,
  ],
  'разделители строк и bidi U+2028-202F': [
    0x2028,
    0x2029,
    0x202A,
    0x202E,
    0x202F,
  ],
  'U+205F-206F (включая bidi-изоляты)': [
    0x205F,
    0x2060,
    0x2064,
    0x2066,
    0x2069,
    0x206F,
  ],
  'брайлевский пробел U+2800': [0x2800],
  'вариационные селекторы U+FE00-FE0F': [0xFE00, 0xFE0F],
  'BOM U+FEFF': [0xFEFF],
  'U+FFF0-FFFC': [0xFFF0, 0xFFF9, 0xFFFB, 0xFFFC],
  'U+110BD, U+110CD': [0x110BD, 0x110CD],
  'U+13430-1343F': [0x13430, 0x1343F],
  'U+1BCA0-1BCA3': [0x1BCA0, 0x1BCA3],
  'U+1D173-1D17A': [0x1D173, 0x1D17A],
  'теги U+E0000-E0FFF': [0xE0000, 0xE0041, 0xE007F, 0xE0FFF],
};

void main() {
  test('обычное имя остаётся как есть', () {
    expect(sanitizeDisplayName('Саша Петров'), 'Саша Петров');
    expect(sanitizeDisplayName('José'), 'José');
    expect(sanitizeDisplayName('山田太郎'), '山田太郎');
  });

  test('пробелы по краям убираются, пустое имя — null', () {
    expect(sanitizeDisplayName('  Саша  '), 'Саша');
    expect(sanitizeDisplayName(''), isNull);
    expect(sanitizeDisplayName('   '), isNull);
    expect(sanitizeDisplayName(_chars([0x00A0])), isNull);
    expect(sanitizeDisplayName(_chars([0x3000])), isNull);
  });

  group('запрещённые символы вырезаются (как в ограничении сервера)', () {
    _forbidden.forEach((name, codes) {
      test(name, () {
        for (final code in codes) {
          expect(
            sanitizeDisplayName('Са${_chars([code])}ша'),
            'Саша',
            reason: 'U+${code.toRadixString(16)} внутри',
          );
          expect(
            sanitizeDisplayName('${_chars([code])}Саша'),
            'Саша',
            reason: 'U+${code.toRadixString(16)} в начале',
          );
        }
      });
    });

    test('имя только из запрещённых символов — null', () {
      expect(sanitizeDisplayName(_chars([0x200B, 0x202E, 0x0A])), isNull);
      expect(sanitizeDisplayName(_chars([0x3164, 0x2800, 0x115F])), isNull);
      expect(sanitizeDisplayName(_chars([0xE0041, 0xE0042])), isNull);
    });

    test('знаки рядом с запрещёнными диапазонами остаются', () {
      for (final code in [0x00A0, 0x00AE, 0x2010, 0x2070, 0xFE10, 0x3165]) {
        expect(
          sanitizeDisplayName('a${_chars([code])}b'),
          'a${_chars([code])}b',
          reason: 'U+${code.toRadixString(16)}',
        );
      }
    });
  });

  group('комбинирующие знаки (zalgo)', () {
    test('до двух подряд остаются', () {
      final two = 'e${_chars([0x0301, 0x0302])}';
      expect(sanitizeDisplayName(two), two);
    });

    test('больше двух подряд обрезаются до двух', () {
      for (final mark in [0x0301, 0x0483, 0x1AB0, 0x1DC0, 0x20D0, 0xFE20]) {
        final zalgo = 'e${_chars(List.filled(10, mark))}x';
        expect(
          sanitizeDisplayName(zalgo),
          'e${_chars([mark, mark])}x',
          reason: 'U+${mark.toRadixString(16)}',
        );
      }
    });

    test('счёт идёт заново после обычного знака', () {
      final s = 'a${_chars([0x301, 0x302])}b${_chars([0x301, 0x302])}';
      expect(sanitizeDisplayName(s), s);
    });

    test('вырезанные знаки не склеивают цепочку', () {
      // Два знака, невидимый между ними и ещё два: после вырезания четыре
      // подряд, остаются два.
      final s = 'e${_chars([0x301, 0x302, 0x200B, 0x303, 0x304])}';
      expect(sanitizeDisplayName(s), 'e${_chars([0x301, 0x302])}');
    });
  });

  test(
    'составные эмодзи (ZWJ) и U+FE0F вырезаются, простой эмодзи остаётся',
    () {
      final family = _chars([0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467]);
      expect(sanitizeDisplayName(family), _chars([0x1F468, 0x1F469, 0x1F467]));
      expect(sanitizeDisplayName(_chars([0x2764, 0xFE0F])), _chars([0x2764]));
      expect(sanitizeDisplayName(_chars([0x1F600])), _chars([0x1F600]));
    },
  );

  test('длина ограничена 64 знаками Unicode, а не единицами UTF-16', () {
    expect(sanitizeDisplayName('я' * 64), 'я' * 64);
    expect(sanitizeDisplayName('я' * 100), 'я' * 64);
    // Эмодзи — один знак, две единицы UTF-16: пара не рвётся.
    final emoji = _chars([0x1F600]) * 70;
    final cut = sanitizeDisplayName(emoji)!;
    expect(cut.runes.length, 64);
    expect(cut, _chars([0x1F600]) * 64);
  });

  test('обрезка по длине не оставляет пробел на конце', () {
    final input = '${'я' * 63} ${'ю' * 10}';
    expect(sanitizeDisplayName(input), 'я' * 63);
  });
}
