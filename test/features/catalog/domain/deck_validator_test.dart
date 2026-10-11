import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/deck_validator.dart';

import '../../../helpers/deck_fixtures.dart';

typedef _Mutation = void Function(Map<String, dynamic> deck);

/// «Плохая» фикстура: хорошая колода + одна поломка.
typedef _BadCase = ({
  String name,
  _Mutation mutate,
  String path,
  String message,
  bool release,
});

_BadCase _bad(
  String name,
  _Mutation mutate, {
  required String path,
  required String message,
  bool release = false,
}) => (
  name: name,
  mutate: mutate,
  path: path,
  message: message,
  release: release,
);

const _mcq = '/items/0/questions/0';
const _open = '/items/0/questions/1';
const _cloze = '/items/1/questions/0';
const _order = '/items/1/questions/1';
const _findError = '/items/2/questions/1';

List<DeckIssue> _validate(Map<String, dynamic> json, {bool release = false}) =>
    validateDeck(Deck.fromJson(json), release: release);

final _badCases = <_BadCase>[
  // Ссылки источников: только абсолютный https.
  for (final url in [
    'http://example.org/a',
    'javascript:alert(1)',
    'file:///etc/passwd',
    '/относительный/путь',
    'example.org/a',
    'https://',
    '',
  ])
    _bad(
      'url источника "$url" не абсолютный https',
      (d) => nodeAt(d, '/sources/0')['url'] = url,
      path: '/sources/0/url',
      message: 'абсолютный https-URL',
    ),
  // Уникальность id.
  _bad(
    'повтор id источника',
    (d) => nodeAt(d, '/sources/1')['id'] = 'src-a',
    path: '/sources/1/id',
    message: 'повторяется',
  ),
  _bad(
    'повтор id знания',
    (d) => nodeAt(d, '/items/1')['id'] = 't.a',
    path: '/items/1/id',
    message: 'повторяется',
  ),
  _bad(
    'повтор id вопроса',
    (d) => nodeAt(d, _open)['id'] = 't.a.q1',
    path: '$_open/id',
    message: 'повторяется',
  ),
  _bad(
    'id вопроса без префикса знания',
    (d) => nodeAt(d, _open)['id'] = 'other.q2',
    path: '$_open/id',
    message: 'должен начинаться с "t.a."',
  ),
  _bad(
    'повтор id опции mcq',
    (d) => nodeAt(d, '$_mcq/payload/options/1')['id'] = 'a',
    path: '$_mcq/payload/options/1/id',
    message: 'повторяется',
  ),
  // refs.source_id существует.
  _bad(
    'ссылка на необъявленный источник',
    (d) => nodeAt(d, '/items/0/refs/0')['source_id'] = 'nope',
    path: '/items/0/refs/0/source_id',
    message: '"nope" не объявлен',
  ),
  _bad(
    'знание без refs',
    (d) => nodeAt(d, '/items/0')['refs'] = <dynamic>[],
    path: '/items/0/refs',
    message: 'хотя бы одна ссылка',
  ),
  // mcq.
  _bad(
    'mcq с одной опцией',
    (d) => (nodeAt(d, '$_mcq/payload')['options'] as List).removeRange(1, 3),
    path: '$_mcq/payload/options',
    message: 'минимум 2',
  ),
  _bad(
    'mcq: correct не из опций',
    (d) => nodeAt(d, '$_mcq/payload')['correct'] = ['a', 'z'],
    path: '$_mcq/payload/correct/1',
    message: '"z" не найден',
  ),
  _bad(
    'mcq: multiple = false и два верных',
    (d) => nodeAt(d, '$_mcq/payload')['multiple'] = false,
    path: '$_mcq/payload/correct',
    message: 'ровно один',
  ),
  // order.
  _bad(
    'order с двумя шагами',
    (d) => (nodeAt(d, '$_order/payload')['steps'] as List).removeLast(),
    path: '$_order/payload/steps',
    message: 'минимум 3',
  ),
  // find_error.
  _bad(
    'find_error: строка за пределами',
    (d) => nodeAt(d, '$_findError/payload')['error_lines'] = [2, 5],
    path: '$_findError/payload/error_lines/1',
    message: 'вне диапазона 1–4',
  ),
  _bad(
    'find_error: пояснение к несуществующей строке',
    (d) => nodeAt(d, '$_findError/payload/line_explanations')['9'] = 'x',
    path: '$_findError/payload/line_explanations/9',
    message: 'вне диапазона',
  ),
  _bad(
    'find_error: нет пояснения к ошибочной строке',
    (d) => nodeAt(d, '$_findError/payload/line_explanations').remove('4'),
    path: '$_findError/payload/line_explanations',
    message: 'нет пояснения для строки 4',
  ),
  // cloze.
  _bad(
    'cloze: плейсхолдер без пропуска',
    (d) => nodeAt(d, _cloze)['prompt'] = '{{x}}, {{y_2}} и {{z}}.',
    path: '$_cloze/prompt',
    message: '{{z}} нет пропуска',
  ),
  _bad(
    'cloze: пропуск без плейсхолдера',
    (d) => nodeAt(d, _cloze)['prompt'] = 'Только {{x}}.',
    path: '$_cloze/payload/blanks/1/id',
    message: 'нет в тексте',
  ),
  _bad(
    'cloze: некорректный плейсхолдер',
    (d) => nodeAt(d, _cloze)['prompt'] = '{{x}} и {{ y_2 }}.',
    path: '$_cloze/prompt',
    message: 'некорректный плейсхолдер',
  ),
  _bad(
    'cloze: незакрытые скобки',
    (d) => nodeAt(d, _cloze)['prompt'] = '{{x}} и {{y_2}} и {{.',
    path: '$_cloze/prompt',
    message: 'незакрытые',
  ),
  _bad(
    'cloze: плейсхолдер дважды',
    (d) => nodeAt(d, _cloze)['prompt'] = '{{x}}, {{x}} и {{y_2}}.',
    path: '$_cloze/prompt',
    message: 'дважды',
  ),
  // open.
  _bad(
    'open: один пункт рубрики',
    (d) => (nodeAt(d, '$_open/payload')['rubric'] as List).removeLast(),
    path: '$_open/payload/rubric',
    message: '2–5 пунктов',
  ),
  _bad(
    'open: шесть пунктов рубрики',
    (d) => (nodeAt(d, '$_open/payload')['rubric'] as List).addAll([
      for (var i = 3; i <= 6; i++)
        {'id': 'p$i', 'text': 'П$i', 'weight': 1, 'required': false},
    ]),
    path: '$_open/payload/rubric',
    message: '2–5 пунктов',
  ),
  _bad(
    'open: нет обязательного пункта',
    (d) => nodeAt(d, '$_open/payload/rubric/0')['required'] = false,
    path: '$_open/payload/rubric',
    message: 'required = true',
  ),
  // Прочее.
  _bad(
    'больше 4 вопросов у знания',
    (d) => (nodeAt(d, '/items/0')['questions'] as List).addAll([
      for (var i = 3; i <= 5; i++)
        {
          'id': 't.a.q$i',
          'type': 'flip',
          'prompt': 'P',
          'payload': {'back': 'B'},
        },
    ]),
    path: '/items/0/questions',
    message: '1–4',
  ),
  _bad(
    'неподдерживаемая schema_version',
    (d) => d['schema_version'] = 2,
    path: '/schema_version',
    message: 'поддерживаются версии 1–1',
  ),
  // --release.
  _bad(
    '--release: знание не approved',
    (d) => nodeAt(d, '/items/1/review')['status'] = 'needs_fix',
    path: '/items/1/review/status',
    message: 'сейчас "needs_fix"',
    release: true,
  ),
];

void main() {
  test('хорошая фикстура проходит и в режиме --release', () {
    final json = readJsonFile(goodDeckPath);
    expect(_validate(json), isEmpty);
    expect(_validate(json, release: true), isEmpty);
  });

  test('sample.json проходит семантику, но не --release (не вычитан)', () {
    final json = readJsonFile(sampleDeckPath);
    expect(_validate(json), isEmpty);
    expect(_validate(json, release: true).map((i) => i.path), [
      '/items/0/review/status',
      '/items/1/review/status',
      '/items/2/review/status',
    ]);
  });

  test('draft проходит без --release', () {
    final json = readJsonFile(goodDeckPath);
    nodeAt(json, '/items/1/review')['status'] = 'draft';
    expect(_validate(json), isEmpty);
  });

  group('плохие фикстуры', () {
    for (final c in _badCases) {
      test(c.name, () {
        final json = readJsonFile(goodDeckPath);
        c.mutate(json);
        final issues = _validate(json, release: c.release);
        expect(
          issues,
          contains(
            isA<DeckIssue>()
                .having((i) => i.path, 'path', c.path)
                .having((i) => i.message, 'message', contains(c.message)),
          ),
          reason: issues.join('\n'),
        );
      });
    }
  });

  test('DeckIssue.toString содержит путь и сообщение', () {
    expect(const DeckIssue('/a/0', 'плохо').toString(), '/a/0: плохо');
  });
}
