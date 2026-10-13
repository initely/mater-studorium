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

    test('похожие кириллические буквы заменяются латинскими (N4)', () {
      // «К7Q2МХ»: К, М, Х — кириллица, как на русской раскладке.
      final typed = String.fromCharCodes([
        0x041A,
        0x37,
        0x51,
        0x32,
        0x041C,
        0x0425,
      ]);
      expect(normalizeDuelCode(typed), 'K7Q2MX');
      // Строчные, с пробелом посередине.
      final lower = String.fromCharCodes([
        0x043A,
        0x37,
        0x71,
        0x20,
        0x32,
        0x043C,
        0x0445,
      ]);
      expect(normalizeDuelCode(lower), 'K7Q2MX');
      // Все десять пар заглавных и строчных.
      const pairs = {
        0x0410: 'A',
        0x0412: 'B',
        0x0415: 'E',
        0x041A: 'K',
        0x041C: 'M',
        0x041D: 'H',
        0x0420: 'P',
        0x0421: 'C',
        0x0422: 'T',
        0x0425: 'X',
      };
      pairs.forEach((cyr, lat) {
        expect(
          normalizeDuelCode('${String.fromCharCode(cyr)}DCDEF'),
          '${lat}DCDEF',
          reason: 'заглавная $lat',
        );
        expect(
          normalizeDuelCode('${String.fromCharCode(cyr + 0x20)}DCDEF'),
          '${lat}DCDEF',
          reason: 'строчная $lat',
        );
      });
    });

    test('кириллица без латинского двойника — null', () {
      // «Ж» не похожа ни на одну букву алфавита кода.
      expect(
        normalizeDuelCode(
          String.fromCharCodes([0x0416, 0x37, 0x51, 0x32, 0x4D, 0x58]),
        ),
        isNull,
      );
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
    });
  });

  test('formatDuelCode: группы по три', () {
    expect(formatDuelCode('K7Q2MX'), 'K7Q 2MX');
    expect(formatDuelCode('K7Q'), 'K7Q');
  });
}
