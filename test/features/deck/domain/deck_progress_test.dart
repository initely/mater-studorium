import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/deck/domain/deck_progress.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

void main() {
  test('стадии FSRS раскладываются на новые, изучаемые, выученные', () {
    final p = DeckProgress.fromStateCounts([
      (state: null, count: 4),
      (state: SrsState.newCard, count: 1),
      (state: SrsState.learning, count: 2),
      (state: SrsState.relearning, count: 3),
      (state: SrsState.review, count: 7),
    ]);

    expect(p.newCount, 5);
    expect(p.learningCount, 5);
    expect(p.masteredCount, 7);
    expect(p.total, 17);
  });

  test('пустая колода: нули', () {
    final p = DeckProgress.fromStateCounts(const []);
    expect(p.total, 0);
    expect(p.newCount, 0);
  });

  test('каждая стадия учтена ровно в одной группе', () {
    for (final s in SrsState.values) {
      final p = DeckProgress.fromStateCounts([(state: s, count: 1)]);
      expect(p.total, 1, reason: '$s');
      expect(
        [p.newCount, p.learningCount, p.masteredCount].where((c) => c == 1),
        hasLength(1),
        reason: '$s',
      );
    }
  });
}
