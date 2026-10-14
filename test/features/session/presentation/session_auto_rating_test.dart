// Оценка форматов с автопроверкой выводится сама (ТЗ §4.1, ADR-38): после
// ответа только вердикт и «Дальше», кнопок самооценки нет; в журнал уходит
// оценка из таблицы `suggestRating` и grade_source = auto.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/app/router.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/presentation/session_screen.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/pump_app.dart';

final _t0 = DateTime.utc(2026, 10, 11, 12);

Finder _key(String key) => find.byKey(Key(key));

Question _question(QuestionType type, String prompt, QuestionPayload payload) =>
    Question(id: 'q1', type: type, prompt: prompt, payload: payload);

Future<FakeSessionRepository> _pump(WidgetTester tester, Question q) async {
  final repo = FakeSessionRepository(
    contents: [
      fakeContent('i1', questions: [q]),
    ],
  );
  final router = GoRouter(
    initialLocation: '/session',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('экран-главный')),
      GoRoute(path: '/decks', builder: (_, _) => const Text('экран-колоды')),
      GoRoute(path: '/session', builder: (_, _) => const SessionScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpRouterApp(
    overrides: [
      routerProvider.overrideWithValue(router),
      sessionRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _t0),
      randomProvider.overrideWithValue(math.Random(1)),
      uuidGeneratorProvider.overrideWithValue(() => 'log-${repo.logs.length}'),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Нет панели самооценки; «Дальше» записывает [rating] с grade_source auto.
Future<void> _expectAuto(
  WidgetTester tester,
  FakeSessionRepository repo,
  Rating rating,
) async {
  expect(find.text('Как хорошо вы это помнили?'), findsNothing);
  expect(_key('rating-again'), findsNothing);
  expect(_key('rating-good'), findsNothing);
  expect(repo.logs, isEmpty, reason: 'до «Дальше» ничего не записано');
  await tester.ensureVisible(_key('rating-next'));
  await tester.tap(_key('rating-next'));
  await tester.pumpAndSettle();
  expect(repo.logs.single.rating, rating);
  expect(repo.logs.single.gradeSource, GradeSource.auto);
}

final _cloze = _question(
  QuestionType.cloze,
  'Трёхстороннее {{a}}.',
  const QuestionPayload.cloze(
    blanks: [
      ClozeBlank(id: 'a', accepted: ['handshake']),
    ],
  ),
);

final _order = _question(
  QuestionType.order,
  'Расставьте шаги',
  QuestionPayload.order(
    steps: [
      for (final id in ['s1', 's2', 's3', 's4'])
        OrderStep(id: id, text: 'Шаг $id'),
    ],
  ),
);

final _findError = _question(
  QuestionType.findError,
  'Где ошибки?',
  const QuestionPayload.findError(
    mode: FindErrorMode.text,
    lines: ['Первое', 'Второе', 'Третье'],
    errorLines: [1, 3],
    lineExplanations: {1: 'ошибка', 3: 'ошибка'},
  ),
);

List<String> _onScreen(WidgetTester tester) {
  final ids = ['s1', 's2', 's3', 's4'];
  final tops = {
    for (final id in ids) id: tester.getTopLeft(find.text('Шаг $id')).dy,
  };
  return ids..sort((a, b) => tops[a]!.compareTo(tops[b]!));
}

Future<void> _solveOrder(WidgetTester tester) async {
  for (var target = 0; target < 3; target++) {
    final id = 's${target + 1}';
    while (_onScreen(tester).indexOf(id) > target) {
      await tester.tap(_key('order-up-$id'));
      await tester.pump();
    }
  }
}

void main() {
  group('cloze', () {
    testWidgets('верно → Good', (tester) async {
      final repo = await _pump(tester, _cloze);
      await tester.enterText(_key('cloze-field-a'), 'handshake');
      await tester.tap(_key('cloze-answer'));
      await tester.pumpAndSettle();
      expect(find.text('Верно'), findsWidgets);
      await _expectAuto(tester, repo, Rating.good);
    });

    testWidgets('опечатка → Hard', (tester) async {
      final repo = await _pump(tester, _cloze);
      await tester.enterText(_key('cloze-field-a'), 'handshak');
      await tester.tap(_key('cloze-answer'));
      await tester.pumpAndSettle();
      expect(find.text('Почти верно'), findsWidgets);
      await _expectAuto(tester, repo, Rating.hard);
    });

    testWidgets('неверно → Again', (tester) async {
      final repo = await _pump(tester, _cloze);
      await tester.enterText(_key('cloze-field-a'), 'udp');
      await tester.tap(_key('cloze-answer'));
      await tester.pumpAndSettle();
      expect(find.text('Неверно'), findsWidgets);
      await _expectAuto(tester, repo, Rating.again);
    });
  });

  group('order', () {
    testWidgets('верный порядок → Good', (tester) async {
      final repo = await _pump(tester, _order);
      await _solveOrder(tester);
      await tester.tap(_key('order-check'));
      await tester.pumpAndSettle();
      await _expectAuto(tester, repo, Rating.good);
    });

    testWidgets('соседние шаги переставлены → Hard', (tester) async {
      final repo = await _pump(tester, _order);
      await _solveOrder(tester);
      await tester.tap(_key('order-down-s1'));
      await tester.pump();
      await tester.tap(_key('order-check'));
      await tester.pumpAndSettle();
      expect(find.text('Почти верно'), findsWidgets);
      await _expectAuto(tester, repo, Rating.hard);
    });

    testWidgets('порядок сильно нарушен → Again', (tester) async {
      final repo = await _pump(tester, _order);
      await _solveOrder(tester);
      await tester.tap(_key('order-down-s1'));
      await tester.pump();
      await tester.tap(_key('order-down-s1'));
      await tester.pump();
      await tester.tap(_key('order-check'));
      await tester.pumpAndSettle();
      expect(find.text('Неверно'), findsWidgets);
      await _expectAuto(tester, repo, Rating.again);
    });
  });

  group('find_error', () {
    testWidgets('найдены все ошибки → Good', (tester) async {
      final repo = await _pump(tester, _findError);
      await tester.tap(_key('find-error-line-1'));
      await tester.pump();
      await tester.tap(_key('find-error-line-3'));
      await tester.pump();
      await tester.tap(_key('find-error-check'));
      await tester.pumpAndSettle();
      await _expectAuto(tester, repo, Rating.good);
    });

    testWidgets('выбрана не та строка → Again', (tester) async {
      final repo = await _pump(tester, _findError);
      await tester.tap(_key('find-error-line-2'));
      await tester.pump();
      await tester.tap(_key('find-error-check'));
      await tester.pumpAndSettle();
      await _expectAuto(tester, repo, Rating.again);
    });
  });
}
