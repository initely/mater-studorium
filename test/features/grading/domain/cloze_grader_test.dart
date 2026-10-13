import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/grading/domain/cloze_grader.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

ClozePayload _payload(Map<String, List<String>> blanks) =>
    QuestionPayload.cloze(
      blanks: [
        for (final e in blanks.entries)
          ClozeBlank(id: e.key, accepted: e.value),
      ],
    ) as ClozePayload;

ClozeBlankVerdict _one(List<String> accepted, String answer) =>
    gradeCloze(_payload({'a': accepted}), {'a': answer}).blanks.single.verdict;

void main() {
  group('нормализация', () {
    test('регистр и пробелы по краям', () {
      expect(_one(['TLS'], '  tls  '), ClozeBlankVerdict.correct);
    });
    test('ё и е равны', () {
      expect(_one(['чёрный'], 'Черный'), ClozeBlankVerdict.correct);
      expect(_one(['черный'], 'чёрный'), ClozeBlankVerdict.correct);
    });
    test('внутренние пробелы схлопываются', () {
      expect(
        _one(['man in the middle'], 'man   in\tthe  middle'),
        ClozeBlankVerdict.correct,
      );
    });
    test('пунктуация по краям отбрасывается, внутри остаётся', () {
      expect(_one(['sql'], '"SQL".'), ClozeBlankVerdict.correct);
      expect(_one(['x-ray'], 'xray'), ClozeBlankVerdict.wrong);
    });
  });

  group('допустимые варианты', () {
    test('подходит любой из accepted', () {
      expect(
        _one(['XSS', 'межсайтовый скриптинг'], 'Межсайтовый скриптинг'),
        ClozeBlankVerdict.correct,
      );
    });
    test('пустой и пробельный ответ неверен', () {
      expect(_one(['xss'], ''), ClozeBlankVerdict.wrong);
      expect(_one(['xss'], '  . '), ClozeBlankVerdict.wrong);
    });
    test('пропуск без ответа в карте неверен', () {
      final grade = gradeCloze(
        _payload({
          'a': ['x'],
        }),
        {},
      );
      expect(grade.outcome, AnswerOutcome.autoIncorrect);
    });
  });

  group('опечатка', () {
    test('в длинном слове принимается как опечатка', () {
      expect(_one(['handshake'], 'handshaek'), ClozeBlankVerdict.wrong);
      expect(_one(['handshake'], 'handshke'), ClozeBlankVerdict.typo);
      expect(_one(['handshake'], 'handshakes'), ClozeBlankVerdict.typo);
    });
    test('в коротком слове не прощается', () {
      expect(_one(['token'], 'tokan'), ClozeBlankVerdict.wrong);
      expect(_one(['xss'], 'xsz'), ClozeBlankVerdict.wrong);
    });
    test('ровно 6 символов: граница включена', () {
      expect(_one(['cookie'], 'cookia'), ClozeBlankVerdict.typo);
    });
    test('два исправления уже неверно', () {
      expect(_one(['handshake'], 'handshaxx'), ClozeBlankVerdict.wrong);
    });
    test('точное совпадение со вторым вариантом важнее опечатки в первом', () {
      expect(
        _one(['handshake', 'handshaky'], 'handshaky'),
        ClozeBlankVerdict.correct,
      );
    });
  });

  group('числа', () {
    test('443 и 443.0 равны', () {
      expect(_one(['443'], '443.0'), ClozeBlankVerdict.correct);
      expect(_one(['443.0'], '443'), ClozeBlankVerdict.correct);
    });
    test('запятая как десятичный разделитель', () {
      expect(_one(['2.5'], '2,5'), ClozeBlankVerdict.correct);
    });
    test('числа не прощают опечатку', () {
      expect(_one(['100000'], '100001'), ClozeBlankVerdict.wrong);
    });
    test('число против слова неверно', () {
      expect(_one(['443'], 'https'), ClozeBlankVerdict.wrong);
    });
  });

  group('несколько пропусков', () {
    final payload = _payload({
      'a': ['tcp'],
      'b': ['handshake'],
    });
    test('все верны: autoCorrect', () {
      final g = gradeCloze(payload, {'a': 'TCP', 'b': 'handshake'});
      expect(g.outcome, AnswerOutcome.autoCorrect);
      expect(g.isCorrect, isTrue);
    });
    test('один с опечаткой: clozeTypo (Hard)', () {
      final g = gradeCloze(payload, {'a': 'tcp', 'b': 'handshke'});
      expect(g.outcome, AnswerOutcome.clozeTypo);
      expect(g.isCorrect, isTrue);
    });
    test(
      'один неверен: autoIncorrect, остальные подсвечены по отдельности',
      () {
        final g = gradeCloze(payload, {'a': 'udp', 'b': 'handshake'});
        expect(g.outcome, AnswerOutcome.autoIncorrect);
        expect(g.blanks[0].verdict, ClozeBlankVerdict.wrong);
        expect(g.blanks[0].expected, 'tcp');
        expect(g.blanks[1].verdict, ClozeBlankVerdict.correct);
        expect(g.isCorrect, isFalse);
      },
    );
    test('неверный пропуск перекрывает опечатку', () {
      final g = gradeCloze(payload, {'a': 'udp', 'b': 'handshke'});
      expect(g.outcome, AnswerOutcome.autoIncorrect);
    });
  });

  test('levenshtein', () {
    expect(levenshtein('', 'abc'), 3);
    expect(levenshtein('kitten', 'sitting'), 3);
    expect(levenshtein('same', 'same'), 0);
  });
}
