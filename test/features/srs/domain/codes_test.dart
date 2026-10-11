import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

void main() {
  test('Rating: коды 1..4 как в FSRS и обратное преобразование', () {
    expect(Rating.values.map((r) => r.code), [1, 2, 3, 4]);
    for (final r in Rating.values) {
      expect(Rating.fromCode(r.code), r);
    }
    expect(() => Rating.fromCode(0), throwsStateError);
  });

  test('SrsState: коды 0..3 как в FSRS и обратное преобразование', () {
    expect(SrsState.values.map((s) => s.code), [0, 1, 2, 3]);
    for (final s in SrsState.values) {
      expect(SrsState.fromCode(s.code), s);
    }
  });

  test('GradeSource: значения как в ТЗ §7.2', () {
    expect(GradeSource.values.map((s) => s.wire), [
      'self',
      'auto',
      'llm',
      'override',
    ]);
    for (final s in GradeSource.values) {
      expect(GradeSource.fromWire(s.wire), s);
    }
  });

  test('QuestionType.wire: snake_case, как в JSON колоды', () {
    expect(QuestionType.findError.wire, 'find_error');
    expect(QuestionType.mcq.wire, 'mcq');
    for (final t in QuestionType.values) {
      expect(QuestionType.fromWire(t.wire), t);
    }
  });
}
