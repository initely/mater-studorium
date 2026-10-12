import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:mater_studorium/features/grading/domain/open_grade_parser.dart';

/// Пример ответа 200 из README `grade-open-answer`.
Map<String, Object?> _ok() => {
  'verdict': 'partial',
  'score': 0.5,
  'points': [
    {'id': 'p1', 'status': 'hit'},
    {'id': 'p2', 'status': 'miss'},
    {'id': 'p3', 'status': 'partial'},
  ],
  'missed': [
    {
      'id': 'p2',
      'text': 'Соль уникальна для каждого пароля',
      'status': 'miss',
      'required': true,
    },
    {
      'id': 'p3',
      'text': 'Соль хранят рядом с хешем',
      'status': 'partial',
      'required': false,
    },
  ],
  'feedback': 'Не объяснено, зачем соль уникальна.',
  'suggested_rating': 2,
  'source': 'llm',
  'cached': false,
  'remaining_quota': 27,
  'quota_reset_at': '2026-10-13T00:00:00.000Z',
};

void main() {
  test('пример из README разбирается целиком', () {
    final g = parseOpenGrade(_ok());
    expect(g.verdict, GradeVerdict.partial);
    expect(g.score, 0.5);
    expect(g.points.map((p) => (p.id, p.status)), [
      ('p1', PointStatus.hit),
      ('p2', PointStatus.miss),
      ('p3', PointStatus.partial),
    ]);
    expect(g.missed, hasLength(2));
    expect(g.missed.first.text, 'Соль уникальна для каждого пароля');
    expect(g.missed.first.required, isTrue);
    expect(g.missed.last.status, PointStatus.partial);
    expect(g.feedback, 'Не объяснено, зачем соль уникальна.');
    expect(g.origin, GradeOrigin.llm);
    expect(g.cached, isFalse);
    expect(g.remainingQuota, 27);
    expect(g.quotaResetAt, DateTime.utc(2026, 10, 13));
  });

  test('все четыре вердикта и оба источника', () {
    for (final v in GradeVerdict.values) {
      expect(parseOpenGrade({..._ok(), 'verdict': v.name}).verdict, v);
    }
    final rule = parseOpenGrade({
      ..._ok(),
      'verdict': 'incorrect',
      'score': 0,
      'points': <Object>[],
      'missed': <Object>[],
      'feedback': '',
      'source': 'rule',
    });
    expect(rule.origin, GradeOrigin.rule);
    expect(rule.points, isEmpty);
    expect(rule.score, 0);
  });

  test('неизвестные поля игнорируются, в том числе вложенные', () {
    final json = _ok()
      ..['model'] = 'x'
      ..['future'] = {'a': 1};
    final g = parseOpenGrade({
      ...json,
      'points': [
        {'id': 'p1', 'status': 'hit', 'evidence': 'не должно быть, но ладно'},
      ],
    });
    expect(g.points, hasLength(1));
  });

  test('необязательные поля: нет квоты, feedback, cached', () {
    final json = _ok()
      ..remove('remaining_quota')
      ..remove('quota_reset_at')
      ..remove('feedback')
      ..remove('cached')
      ..remove('suggested_rating');
    final g = parseOpenGrade(json);
    expect(g.remainingQuota, isNull);
    expect(g.quotaResetAt, isNull);
    expect(g.feedback, '');
    expect(g.cached, isFalse);
  });

  test('мусор в квоте не ломает разбор, а просто не показывается', () {
    for (final bad in <Object?>[-1, 'много', 2.5, null, double.nan]) {
      final g = parseOpenGrade({..._ok(), 'remaining_quota': bad});
      expect(g.remainingQuota, isNull, reason: '$bad');
    }
    expect(
      parseOpenGrade({..._ok(), 'quota_reset_at': 'вчера'}).quotaResetAt,
      isNull,
    );
    expect(parseOpenGrade({..._ok(), 'remaining_quota': 0}).remainingQuota, 0);
    expect(
      parseOpenGrade({..._ok(), 'remaining_quota': 3.0}).remainingQuota,
      3,
    );
  });

  group('нарушение контракта — OpenGradeFormatException', () {
    void bad(String name, Object? json) => test(name, () {
      expect(
        () => parseOpenGrade(json),
        throwsA(isA<OpenGradeFormatException>()),
      );
    });

    bad('не объект', 'ok');
    bad('null', null);
    bad('список', <Object>[]);
    bad('нет verdict', _ok()..remove('verdict'));
    bad('неизвестный verdict', {..._ok(), 'verdict': 'great'});
    bad('verdict не строка', {..._ok(), 'verdict': 1});
    bad('нет score', _ok()..remove('score'));
    bad('score не число', {..._ok(), 'score': '0.5'});
    bad('score больше 1', {..._ok(), 'score': 1.01});
    bad('score меньше 0', {..._ok(), 'score': -0.1});
    bad('score NaN', {..._ok(), 'score': double.nan});
    bad('нет source', _ok()..remove('source'));
    bad('неизвестный source', {..._ok(), 'source': 'human'});
    bad('feedback не строка', {..._ok(), 'feedback': 5});
    bad('cached не bool', {..._ok(), 'cached': 'no'});
    bad('points не список', {..._ok(), 'points': 'p1'});
    bad('пункт не объект', {
      ..._ok(),
      'points': ['p1'],
    });
    bad('статус пункта неизвестен', {
      ..._ok(),
      'points': [
        {'id': 'p1', 'status': 'maybe'},
      ],
    });
    bad('у пункта нет id', {
      ..._ok(),
      'points': [
        {'status': 'hit'},
      ],
    });
    bad('missed со статусом hit', {
      ..._ok(),
      'missed': [
        {'id': 'p1', 'text': 't', 'status': 'hit', 'required': true},
      ],
    });
    bad('у missed нет текста', {
      ..._ok(),
      'missed': [
        {'id': 'p1', 'status': 'miss', 'required': true},
      ],
    });
    bad('у missed нет required', {
      ..._ok(),
      'missed': [
        {'id': 'p1', 'text': 't', 'status': 'miss'},
      ],
    });
  });
}
