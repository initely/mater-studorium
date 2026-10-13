import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/duel/domain/duel_code.dart';

void main() {
  test('алфавит: 31 знак, нет I, L, O, 0, 1', () {
    expect(kDuelCodeAlphabet.length, 31);
    expect(kDuelCodeAlphabet.split('').toSet().length, 31);
    for (final c in ['I', 'L', 'O', '0', '1']) {
      expect(kDuelCodeAlphabet, isNot(contains(c)), reason: c);
    }
    expect(kDuelCodeLength, 6);
  });

  group('normalizeDuelCode', () {
    test('верный код проходит как есть', () {
      expect(normalizeDuelCode('K7Q2MX'), 'K7Q2MX');
    });

    test('регистр и пробелы не важны: код читают вслух группами', () {
      expect(normalizeDuelCode(' k7q 2mx '), 'K7Q2MX');
      expect(normalizeDuelCode('k7q\n2mx'), 'K7Q2MX');
    });

    test('неверная длина — null', () {
      expect(normalizeDuelCode(''), isNull);
      expect(normalizeDuelCode('K7Q2M'), isNull);
      expect(normalizeDuelCode('K7Q2MXA'), isNull);
    });

    test('знаки вне алфавита — null (в том числе похожие I, L, O, 0, 1)', () {
      for (final bad in ['I7Q2MX', 'L7Q2MX', 'O7Q2MX', '07Q2MX', '17Q2MX']) {
        expect(normalizeDuelCode(bad), isNull, reason: bad);
      }
      expect(normalizeDuelCode('K7Q2M!'), isNull);
      expect(normalizeDuelCode('К7Q2MX'), isNull); // кириллическая К
    });
  });

  test('formatDuelCode: группы по три', () {
    expect(formatDuelCode('K7Q2MX'), 'K7Q 2MX');
    expect(formatDuelCode('K7Q'), 'K7Q');
  });
}
