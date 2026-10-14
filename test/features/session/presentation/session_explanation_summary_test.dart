// Разбор по желанию и итоги внутри экрана сессии (T14: AC6.1, AC6.2, AC3.3,
// ТЗ §8.2, п. 3 и 5).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/app/router.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/domain/item_ref.dart';
import 'package:mater_studorium/features/catalog/domain/local_item.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/explanations/data/link_launcher.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/domain/item_content.dart';
import 'package:mater_studorium/features/session/domain/session_settings.dart';
import 'package:mater_studorium/features/session/presentation/session_controller.dart';
import 'package:mater_studorium/features/session/presentation/session_screen.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/pump_app.dart';

final _t0 = DateTime.utc(2026, 10, 11, 12);

class _MutableClock {
  DateTime now = _t0;
  void advance(Duration d) => now = now.add(d);
}

Question _mcq(String id, {String? explanationShort}) => Question(
  id: id,
  type: QuestionType.mcq,
  prompt: 'Вопрос $id',
  explanationShort: explanationShort,
  payload: const QuestionPayload.mcq(
    options: [
      McqOption(id: 'a', text: 'Вариант A'),
      McqOption(id: 'b', text: 'Вариант B'),
    ],
    correct: ['a'],
    multiple: false,
  ),
);

Question _flip(String id) => Question(
  id: id,
  type: QuestionType.flip,
  prompt: 'Вопрос $id',
  payload: const QuestionPayload.flip(back: 'Оборот'),
);

const _source = ItemRef(
  sourceId: 'owasp',
  quote: 'цитата',
  sourceTitle: 'OWASP XSS',
  url: 'https://owasp.org/www-community/attacks/xss/',
  license: 'CC BY-SA 4.0',
);

ItemContent _content(
  String id,
  Question question, {
  String short = 'Коротко знание',
  String long = 'Подробно знание',
  List<ItemRef> refs = const [],
}) => ItemContent(
  item: LocalItem(
    id: id,
    deckId: 'd1',
    title: id,
    fact: 'Факт',
    explanationShort: short,
    explanationLong: long,
    refs: refs,
    retired: false,
  ),
  deckVersion: 1,
  questions: [question],
);

class _Launcher {
  final calls = <Uri>[];
  Future<bool> call(Uri uri) async {
    calls.add(uri);
    return true;
  }
}

Future<_Launcher> _pump(
  WidgetTester tester,
  FakeSessionRepository repo,
  _MutableClock clock, {
  List<Override> overrides = const [],
}) async {
  final launcher = _Launcher();
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
      clockProvider.overrideWithValue(() => clock.now),
      randomProvider.overrideWithValue(math.Random(1)),
      uuidGeneratorProvider.overrideWithValue(() => 'log-${repo.logs.length}'),
      linkLauncherProvider.overrideWithValue(launcher.call),
      ...overrides,
    ],
  );
  await tester.pumpAndSettle();
  return launcher;
}

Finder _key(String key) => find.byKey(Key(key));

void main() {
  group('разбор в сессии (AC6.1, AC6.2)', () {
    testWidgets('до ответа разбора нет; после ответа он свёрнут', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _mcq('q1'))],
      );
      await _pump(tester, repo, _MutableClock());

      expect(_key('explanation-short-toggle'), findsNothing);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      expect(_key('explanation-short-toggle'), findsOneWidget);
      expect(_key('explanation-long-toggle'), findsOneWidget);
      expect(_key('explanation-short'), findsNothing);
      expect(_key('explanation-long'), findsNothing);
      // Разбор ниже панели оценки (ТЗ §8.2, п. 3).
      expect(
        tester.getTopLeft(_key('explanation-short-toggle')).dy,
        greaterThan(tester.getTopLeft(_key('rating-next')).dy),
      );
    });

    testWidgets('AC6.1: «Дальше» доступна сразу, разбор открывать не нужно', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _mcq('q1')), _content('i2', _mcq('q2'))],
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(_key('rating-next')).onPressed,
        isNotNull,
      );
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();

      expect(repo.logs, hasLength(1));
      expect(find.text('Вопрос 2 из 2'), findsOneWidget);
      // У нового вопроса разбор снова свёрнут и скрыт до ответа.
      expect(_key('explanation-short-toggle'), findsNothing);
    });

    testWidgets('«Коротко» берёт разбор знания; оценка при открытом разборе', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _mcq('q1')), _content('i2', _mcq('q2'))],
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-b'));
      await tester.pumpAndSettle();

      await tester.tap(_key('explanation-short-toggle'));
      await tester.pumpAndSettle();
      expect(find.text('Коротко знание'), findsOneWidget);

      // Открытый разбор не мешает оценке.
      await tester.ensureVisible(_key('rating-next'));
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();
      expect(repo.logs.single.rating, Rating.again);
      expect(find.text('Вопрос 2 из 2'), findsOneWidget);
      expect(find.text('Коротко знание'), findsNothing);
    });

    testWidgets('разбор вопроса переопределяет разбор знания (ТЗ §4.4)', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [
          _content('i1', _mcq('q1', explanationShort: 'Коротко вопрос')),
        ],
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      await tester.tap(_key('explanation-short-toggle'));
      await tester.pumpAndSettle();

      expect(find.text('Коротко вопрос'), findsOneWidget);
      expect(find.text('Коротко знание'), findsNothing);
    });

    testWidgets('«Подробнее» с источником: https открывается во внешнем', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [
          _content(
            'i1',
            _mcq('q1'),
            long: '**Как работает.**',
            refs: [_source],
          ),
        ],
      );
      final launcher = await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Как работает.', findRichText: true),
        findsOneWidget,
      );
      await tester.ensureVisible(_key('explanation-source-0-open'));
      await tester.tap(_key('explanation-source-0-open'));
      await tester.pumpAndSettle();
      expect(launcher.calls, [Uri.parse(_source.url)]);
      // Сессия при этом не сдвинулась и ничего не записала.
      expect(repo.logs, isEmpty);
    });

    testWidgets('знание без разбора: пустое состояние, оценка работает', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _mcq('q1'), short: '', long: '')],
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      expect(_key('explanation-empty'), findsOneWidget);
      expect(find.text('К этому знанию разбора нет.'), findsOneWidget);
      expect(_key('explanation-short-toggle'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();
      expect(repo.logs, hasLength(1));
    });
  });

  group('итоги сессии (§8.2, п. 5)', () {
    testWidgets('повторено, верно, неверно, самооценка, время', (tester) async {
      final repo = FakeSessionRepository(
        contents: [
          _content('i1', _flip('q1')),
          _content('i2', _mcq('q2')),
          _content('i3', _mcq('q3')),
        ],
      );
      final clock = _MutableClock();
      await _pump(tester, repo, clock);

      clock.advance(const Duration(seconds: 30));
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();

      clock.advance(const Duration(seconds: 20));
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();

      clock.advance(const Duration(seconds: 45));
      await tester.tap(_key('mcq-option-b'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();

      expect(_key('session-summary-title'), findsOneWidget);
      expect(find.text('Повторено: 3'), findsOneWidget);
      expect(find.text('Верно: 1'), findsOneWidget);
      expect(find.text('Неверно: 1'), findsOneWidget);
      expect(find.text('По самооценке: 1'), findsOneWidget);
      expect(find.text('Время: 1 мин 35 с'), findsOneWidget);
      expect(_key('session-more'), findsOneWidget);
      expect(find.text('Ещё 5 минут'), findsOneWidget);
      expect(find.text('На главную'), findsOneWidget);
    });

    testWidgets('«Скоро повторить»: ближайшие due из локального расписания', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _mcq('q1')), _content('i9', _mcq('q9'))],
        states: {'i9': fakeState('i9', _t0.add(const Duration(hours: 3)))},
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-b'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-next')); // «Снова»: повтор скоро
      await tester.pumpAndSettle();

      expect(_key('session-summary-title'), findsOneWidget);
      expect(find.text('Скоро повторить'), findsOneWidget);
      expect(find.text('i9: через 3 ч'), findsOneWidget);
      expect(find.textContaining('i1: через'), findsOneWidget);
    });

    testWidgets('расписание дальше суток: только «Следующее повторение»', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _flip('q1')), _content('i9', _mcq('q9'))],
        states: {'i9': fakeState('i9', _t0.add(const Duration(days: 2)))},
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();

      expect(find.text('Скоро повторить'), findsOneWidget);
      expect(_key('session-summary-next'), findsOneWidget);
      expect(find.text('Следующее повторение — через 2 дн.'), findsOneWidget);
    });

    testWidgets('«Ещё 5 минут» начинает новую сессию с чистыми итогами', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _flip('q1')), _content('i2', _flip('q2'))],
      );
      await _pump(
        tester,
        repo,
        _MutableClock(),
        overrides: [
          sessionSettingsProvider.overrideWithValue(
            const SessionSettings(sessionSize: 1),
          ),
        ],
      );
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();
      expect(find.text('Повторено: 1'), findsOneWidget);

      await tester.tap(_key('session-more'));
      await tester.pumpAndSettle();

      expect(_key('session-summary-title'), findsNothing);
      expect(find.text('Вопрос q2'), findsOneWidget);
      expect(find.text('Вопрос 1 из 1'), findsOneWidget);
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();
      expect(find.text('Повторено: 1'), findsOneWidget);
      expect(repo.logs, hasLength(2));
    });

    testWidgets('«Ещё 5 минут», когда повторять нечего: пустое состояние', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _flip('q1'))],
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();

      await tester.tap(_key('session-more'));
      await tester.pumpAndSettle();
      expect(find.text('Всё повторено 🎉'), findsOneWidget);
      expect(_key('session-empty-next'), findsOneWidget);
    });

    testWidgets('«На главную» уводит на главный', (tester) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _flip('q1'))],
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();

      await tester.tap(_key('session-home'));
      await tester.pumpAndSettle();
      expect(find.text('экран-главный'), findsOneWidget);
    });

    testWidgets('итоги: тап-цели не меньше 48 dp, строки не только цветом', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = FakeSessionRepository(
        contents: [_content('i1', _mcq('q1'))],
      );
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.getSize(_key('session-more')).height, greaterThan(47));
      expect(tester.getSize(_key('session-home')).height, greaterThan(47));
      expect(
        find.descendant(
          of: _key('session-summary-correct'),
          matching: find.byIcon(Icons.check_circle_outline),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Верно: 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('сессия без ответов (завершена вручную): итоги без цифр', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _flip('q1'))],
      );
      await _pump(tester, repo, _MutableClock());
      // Запасной выход: закрываем сессию, ничего не ответив.
      final element = tester.element(_key('flip-show'));
      final container = ProviderScope.containerOf(element);
      container.read(sessionControllerProvider.notifier).finish();
      await tester.pumpAndSettle();

      expect(find.text('Повторено: 0'), findsOneWidget);
      expect(_key('session-summary-correct'), findsNothing);
      expect(_key('session-summary-time'), findsNothing);
      expect(_key('session-more'), findsOneWidget);
    });
  });

  group('пустое состояние (AC3.3)', () {
    testWidgets('лимит новых выбран, но есть ближайшее: время и «Взять»', (
      tester,
    ) async {
      final repo = FakeSessionRepository(
        contents: [_content('i1', _mcq('q1')), _content('i2', _mcq('q2'))],
        states: {'i1': fakeState('i1', _t0.add(const Duration(hours: 3)))},
      );
      await _pump(
        tester,
        repo,
        _MutableClock(),
        overrides: [
          sessionSettingsProvider.overrideWithValue(
            const SessionSettings(newPerDay: 0),
          ),
        ],
      );

      expect(find.text('Всё повторено 🎉'), findsOneWidget);
      expect(find.text('Следующее повторение — через 3 ч'), findsOneWidget);
      expect(find.text('Взять 5 новых'), findsOneWidget);
      expect(tester.getSize(_key('session-take-new')).height, greaterThan(47));
      await tester.tap(_key('session-take-new'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос q2'), findsOneWidget);
    });
  });
}
