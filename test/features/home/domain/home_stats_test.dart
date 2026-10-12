// Подсчёт статистики главного экрана (T18): те же правила, что у очереди.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/home/domain/home_stats.dart';
import 'package:mater_studorium/features/session/domain/session_queue_builder.dart';
import 'package:mater_studorium/features/session/domain/session_settings.dart';

import '../../../helpers/fake_session_repository.dart';

HomeStatsCalculator calculator(
  FakeSessionRepository repo, {
  Set<QuestionType>? supported = const {QuestionType.mcq, QuestionType.flip},
}) => HomeStatsCalculator(
  repository: repo,
  builder: SessionQueueBuilder(
    repository: repo,
    random: math.Random(1),
    utcOffsetAt: (_) => Duration.zero,
    supportedTypes: supported,
  ),
);

final past = fakeNow.subtract(const Duration(hours: 2));

void main() {
  test('повторения и новые считаются раздельно', () async {
    final repo = FakeSessionRepository(
      contents: [
        for (final id in ['a', 'b', 'n1', 'n2', 'n3']) fakeContent(id),
      ],
      states: {'a': fakeState('a', past), 'b': fakeState('b', past)},
    );

    final stats = await calculator(repo)
        .compute(now: fakeNow, settings: const SessionSettings());

    expect(stats.dueCount, 2);
    expect(stats.newCount, 3);
    expect(stats.queueLength, 5);
    expect(stats.hasWork, isTrue);
    expect(stats.moreNewAvailable, isFalse);
  });

  test('новые ограничены остатком дневного лимита', () async {
    final repo = FakeSessionRepository(
      contents: [for (var i = 0; i < 20; i++) fakeContent('n$i')],
      // Три знания впервые показаны сегодня (в 00:00:01 UTC) и вчера.
      logs: [
        fakeLog('x1', DateTime.utc(2026, 10, 11, 0, 0, 1)),
        fakeLog('x2', DateTime.utc(2026, 10, 11, 5)),
        fakeLog('x3', DateTime.utc(2026, 10, 11, 11)),
        fakeLog('y', DateTime.utc(2026, 10, 10, 23)),
      ],
    );

    final stats = await calculator(repo)
        .compute(now: fakeNow, settings: const SessionSettings(newPerDay: 5));

    expect(stats.newCount, 2);
    expect(stats.queueLength, 2);
  });

  test('граница суток берётся из пояса пользователя', () async {
    final repo = FakeSessionRepository(
      contents: [for (var i = 0; i < 20; i++) fakeContent('n$i')],
      // 23:30 UTC 10 октября — это уже 11 октября в поясе UTC+2.
      logs: [fakeLog('x1', DateTime.utc(2026, 10, 10, 23, 30))],
    );
    final calc = HomeStatsCalculator(
      repository: repo,
      builder: SessionQueueBuilder(
        repository: repo,
        random: math.Random(1),
        utcOffsetAt: (_) => const Duration(hours: 2),
        supportedTypes: const {QuestionType.mcq},
      ),
    );

    final stats = await calc.compute(
      now: fakeNow,
      settings: const SessionSettings(newPerDay: 5),
    );

    expect(stats.newCount, 4);
  });

  test('лимит исчерпан: moreNewAvailable, сессия пуста', () async {
    final repo = FakeSessionRepository(
      contents: [for (var i = 0; i < 12; i++) fakeContent('n$i')],
      logs: [for (var i = 0; i < 10; i++) fakeLog('x$i', fakeNow)],
    );

    final stats = await calculator(repo)
        .compute(now: fakeNow, settings: const SessionSettings());

    expect(stats.newCount, 0);
    expect(stats.hasWork, isFalse);
    expect(stats.moreNewAvailable, isTrue);
  });

  test('всё повторено: nextDue из очереди, нового нет', () async {
    final next = fakeNow.add(const Duration(hours: 5));
    final repo = FakeSessionRepository(
      contents: [fakeContent('a')],
      states: {'a': fakeState('a', next)},
    );

    final stats = await calculator(repo)
        .compute(now: fakeNow, settings: const SessionSettings());

    expect(stats.dueCount, 0);
    expect(stats.newCount, 0);
    expect(stats.hasWork, isFalse);
    expect(stats.moreNewAvailable, isFalse);
    expect(stats.nextDue, next);
  });

  test('dueCount — все повторения, а не потолок размера сессии', () async {
    final repo = FakeSessionRepository(
      contents: [for (var i = 0; i < 8; i++) fakeContent('d$i')],
      states: {for (var i = 0; i < 8; i++) 'd$i': fakeState('d$i', past)},
    );

    final stats = await calculator(repo)
        .compute(now: fakeNow, settings: const SessionSettings(sessionSize: 5));

    expect(stats.dueCount, 8);
    expect(stats.queueLength, 5);
  });

  test('знание без поддерживаемого формата в счётчики не попадает', () async {
    final repo = FakeSessionRepository(
      contents: [
        fakeContent('ok'),
        // Только open: в реестре MVP-a нет модуля, в очередь не попадёт.
        fakeContent(
          'open-only',
          questions: [fakeQuestion('open-only.q', QuestionType.open)],
        ),
      ],
    );

    final stats = await calculator(repo)
        .compute(now: fakeNow, settings: const SessionSettings());

    expect(stats.newCount, 1);
  });

  test('без колод и знаний: пусто и нечего брать', () async {
    final stats = await calculator(FakeSessionRepository())
        .compute(now: fakeNow, settings: const SessionSettings());

    expect(stats.dueCount, 0);
    expect(stats.newCount, 0);
    expect(stats.hasWork, isFalse);
    expect(stats.moreNewAvailable, isFalse);
    expect(stats.nextDue, isNull);
  });
}
