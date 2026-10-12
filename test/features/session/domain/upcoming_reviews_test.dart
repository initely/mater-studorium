import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/session/domain/upcoming_reviews.dart';

import '../../../helpers/fake_session_repository.dart';

final _now = DateTime.utc(2026, 10, 11, 12);

FakeSessionRepository _repo(Map<String, Duration> dueIn) =>
    FakeSessionRepository(
      contents: [for (final id in dueIn.keys) fakeContent(id)],
      states: {
        for (final e in dueIn.entries)
          e.key: fakeState(e.key, _now.add(e.value)),
      },
    );

void main() {
  test('нет расписания: пусто', () async {
    final u = await UpcomingReviews.load(_repo({}), now: _now);
    expect(u.isEmpty, isTrue);
    expect(u.items, isEmpty);
    expect(u.nextDue, isNull);
  });

  test('ближайшие по due, не больше трёх; остальные — «ещё»', () async {
    final u = await UpcomingReviews.load(
      _repo({
        'e': const Duration(hours: 5),
        'a': const Duration(minutes: 10),
        'd': const Duration(hours: 3),
        'b': const Duration(minutes: 30),
        'c': const Duration(hours: 1),
      }),
      now: _now,
    );
    expect(u.items.map((i) => i.title), ['a', 'b', 'c']);
    expect(u.items.first.due, _now.add(const Duration(minutes: 10)));
    expect(u.total, 5);
    expect(u.more, 2);
    expect(u.nextDue, isNull);
    expect(u.isEmpty, isFalse);
  });

  test('просроченные, не попавшие в сессию, идут первыми', () async {
    final u = await UpcomingReviews.load(
      _repo({
        'soon': const Duration(hours: 2),
        'overdue': const Duration(hours: -1),
      }),
      now: _now,
    );
    expect(u.items.map((i) => i.title), ['overdue', 'soon']);
    expect(u.items.first.due.isAfter(_now), isFalse);
  });

  test('дальше окна 24 ч — только время следующего повторения', () async {
    final u = await UpcomingReviews.load(
      _repo({'far': const Duration(days: 4)}),
      now: _now,
    );
    expect(u.items, isEmpty);
    expect(u.total, 0);
    expect(u.nextDue, _now.add(const Duration(days: 4)));
    expect(u.isEmpty, isFalse);
  });

  test('знание на границе окна попадает в список', () async {
    final u = await UpcomingReviews.load(
      _repo({'edge': kUpcomingHorizon}),
      now: _now,
    );
    expect(u.items.map((i) => i.title), ['edge']);
  });
}
