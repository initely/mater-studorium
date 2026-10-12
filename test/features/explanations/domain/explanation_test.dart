import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/item_ref.dart';
import 'package:mater_studorium/features/catalog/domain/local_item.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/explanations/domain/explanation.dart';
import 'package:mater_studorium/features/explanations/domain/safe_link.dart';

LocalItem _item({
  String short = 'Коротко знание',
  String long = 'Подробно знание',
  List<ItemRef> refs = const [],
}) => LocalItem(
  id: 'i1',
  deckId: 'd1',
  title: 'Знание',
  fact: 'Факт',
  explanationShort: short,
  explanationLong: long,
  refs: refs,
  retired: false,
);

Question _question({String? short}) => Question(
  id: 'q1',
  type: QuestionType.mcq,
  prompt: 'Вопрос',
  explanationShort: short,
  payload: const QuestionPayload.mcq(
    options: [
      McqOption(id: 'a', text: 'A'),
      McqOption(id: 'b', text: 'B'),
    ],
    correct: ['a'],
    multiple: false,
  ),
);

const _ref = ItemRef(
  sourceId: 's1',
  quote: 'цитата',
  sourceTitle: 'OWASP',
  url: 'https://owasp.org/x',
  license: 'CC BY-SA 4.0',
);

void main() {
  group('Explanation.of', () {
    test('«Коротко» берётся у знания, «Подробнее» тоже', () {
      final e = Explanation.of(_item(refs: [_ref]), _question());
      expect(e.short, 'Коротко знание');
      expect(e.long, 'Подробно знание');
      expect(e.sources, [_ref]);
      expect(e.isEmpty, isFalse);
    });

    test('вопрос переопределяет «Коротко» знания (ТЗ §4.4)', () {
      final e = Explanation.of(_item(), _question(short: 'Коротко вопрос'));
      expect(e.short, 'Коротко вопрос');
      expect(e.long, 'Подробно знание');
    });

    test('пустое переопределение вопроса не затирает разбор знания', () {
      expect(Explanation.of(_item(), _question(short: '  ')).short, isNotNull);
      expect(
        Explanation.of(_item(), _question(short: '  ')).short,
        'Коротко знание',
      );
    });

    test('пустые тексты и пробелы считаются отсутствующими', () {
      final e = Explanation.of(_item(short: ' ', long: '\n'), _question());
      expect(e.short, isNull);
      expect(e.long, isNull);
      expect(e.hasShort, isFalse);
      expect(e.hasLong, isFalse);
      expect(e.isEmpty, isTrue);
    });

    test('только источники: «Подробнее» есть, «Коротко» нет', () {
      final e = Explanation.of(
        _item(short: '', long: '', refs: [_ref]),
        _question(),
      );
      expect(e.hasShort, isFalse);
      expect(e.hasLong, isTrue);
      expect(e.isEmpty, isFalse);
    });
  });

  group('parseSafeLink (ревью T10, AC6.2)', () {
    test('https с хостом разрешён', () {
      expect(
        parseSafeLink('https://owasp.org/www-community/attacks/xss/'),
        Uri.parse('https://owasp.org/www-community/attacks/xss/'),
      );
      expect(parseSafeLink('  https://example.com  '), isNotNull);
      expect(parseSafeLink('HTTPS://example.com'), isNotNull);
    });

    test('прочее не открывается', () {
      for (final bad in [
        'http://example.com',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'ftp://example.com',
        'intent://x#Intent;scheme=https;end',
        'data:text/html,<b>x</b>',
        '//example.com/path',
        '/relative/path',
        'example.com',
        'https://',
        'https:///path',
        'https://user:pass@example.com',
        'https://user@example.com',
        '',
        '   ',
        'https://exa mple.com',
      ]) {
        expect(parseSafeLink(bad), isNull, reason: bad);
      }
    });
  });
}
