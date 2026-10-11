import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/app/router.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/questions/registry.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/domain/item_content.dart';
import 'package:mater_studorium/features/session/domain/review_log.dart';
import 'package:mater_studorium/features/session/domain/session_settings.dart';
import 'package:mater_studorium/features/session/presentation/session_screen.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/pump_app.dart';

final _t0 = DateTime.utc(2026, 10, 11, 12);

class _MutableClock {
  DateTime now = _t0;
  void advance(Duration d) => now = now.add(d);
}

/// Репозиторий с управляемыми отказами и счётчиком построений очереди.
class _Repo extends FakeSessionRepository {
  _Repo({super.contents, super.states});

  /// Сколько первых записей ответа завершится `LocalStorageError`.
  int failWrites = 0;

  /// Сколько первых запросов `dueStates` завершится ошибкой.
  int failReads = 0;

  int queueBuilds = 0;

  @override
  Future<List<ItemState>> dueStates({
    required DateTime now,
    Set<String>? deckIds,
  }) async {
    queueBuilds++;
    if (failReads > 0) {
      failReads--;
      throw const LocalStorageError('чтение не удалось');
    }
    return super.dueStates(now: now, deckIds: deckIds);
  }

  @override
  Future<void> recordReview({
    required ReviewLog log,
    required ItemState state,
  }) async {
    if (failWrites > 0) {
      failWrites--;
      throw const LocalStorageError('запись не удалась');
    }
    return super.recordReview(log: log, state: state);
  }
}

Question _mcq(String id, {List<String> correct = const ['a']}) => Question(
  id: id,
  type: QuestionType.mcq,
  prompt: 'Вопрос $id',
  payload: QuestionPayload.mcq(
    options: const [
      McqOption(id: 'a', text: 'Вариант A'),
      McqOption(id: 'b', text: 'Вариант B'),
      McqOption(id: 'c', text: 'Вариант C'),
    ],
    correct: correct,
    multiple: correct.length > 1,
  ),
);

Question _flip(String id) => Question(
  id: id,
  type: QuestionType.flip,
  prompt: 'Вопрос $id',
  payload: const QuestionPayload.flip(back: 'Оборот'),
);

ItemContent _item(String id, Question question) =>
    fakeContent(id, questions: [question]);

/// Три новых знания по порядку: flip, mcq (один ответ), mcq (два ответа).
_Repo _threeItems() => _Repo(
  contents: [
    _item('i1', _flip('q1')),
    _item('i2', _mcq('q2')),
    _item('i3', _mcq('q3', correct: ['a', 'b'])),
  ],
);

/// Экран на настоящем роутере: `/` и `/decks` — заглушки.
Future<void> _pump(
  WidgetTester tester,
  _Repo repo,
  _MutableClock clock, {
  List<Override> overrides = const [],
}) async {
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
      ...overrides,
    ],
  );
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(Key(key));

void main() {
  group('поток вопросов', () {
    testWidgets('flip → mcq → mcq(несколько): ответы пишутся, затем итоги', (
      tester,
    ) async {
      final repo = _threeItems();
      final clock = _MutableClock();
      await _pump(tester, repo, clock);

      // 1. flip: оборот, самооценка без подсказки.
      expect(find.text('Вопрос 1 из 3'), findsOneWidget);
      expect(find.text('Осталось 5:00'), findsOneWidget);
      expect(find.text('Вопрос q1'), findsOneWidget);
      clock.advance(const Duration(seconds: 4));
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      expect(find.text('Оборот'), findsOneWidget);
      expect(find.text('Выберите оценку сами'), findsOneWidget);
      expect(_key('verdict-banner'), findsNothing);
      // «Дальше» без подсказки недоступна.
      expect(
        tester.widget<FilledButton>(_key('rating-next')).onPressed,
        isNull,
      );
      await tester.tap(_key('rating-easy'));
      await tester.pumpAndSettle();

      expect(repo.logs, hasLength(1));
      final flipLog = repo.logs.single;
      expect(flipLog.questionId, 'q1');
      expect(flipLog.questionType, QuestionType.flip);
      expect(flipLog.rating, Rating.easy);
      expect(flipLog.gradeSource, GradeSource.self);
      expect(flipLog.durationMs, 4000);
      expect(repo.states['i1']!.lastQuestionId, 'q1');

      // 2. mcq: верный ответ, «Дальше» принимает предложенную Good.
      expect(find.text('Вопрос 2 из 3'), findsOneWidget);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      expect(find.text('Верно'), findsWidgets);
      expect(find.text('Предложенная оценка: Хорошо'), findsOneWidget);
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();

      expect(repo.logs, hasLength(2));
      expect(repo.logs.last.rating, Rating.good);
      expect(repo.logs.last.gradeSource, GradeSource.auto);
      expect(repo.logs.last.questionType, QuestionType.mcq);

      // 3. mcq с двумя верными, оба выбраны.
      expect(find.text('Вопрос 3 из 3'), findsOneWidget);
      await tester.tap(_key('mcq-option-a'));
      await tester.pump();
      await tester.tap(_key('mcq-option-b'));
      await tester.pump();
      await tester.tap(_key('mcq-answer'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();

      expect(repo.logs, hasLength(3));
      expect(repo.states.keys, {'i1', 'i2', 'i3'});
      // Очередь кончилась: заглушка итогов, таймера уже нет.
      expect(_key('session-summary-title'), findsOneWidget);
      expect(find.text('Повторено: 3'), findsOneWidget);
      expect(_key('session-time'), findsNothing);
    });

    testWidgets('неверный ответ: вердикт и предложенная Снова', (tester) async {
      final repo = _Repo(contents: [_item('i1', _mcq('q1'))]);
      await _pump(tester, repo, _MutableClock());

      await tester.tap(_key('mcq-option-c'));
      await tester.pumpAndSettle();

      expect(_key('verdict-banner'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('verdict-banner'),
          matching: find.text('Неверно'),
        ),
        findsOneWidget,
      );
      expect(find.text('Предложенная оценка: Снова'), findsOneWidget);
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();
      expect(repo.logs.single.rating, Rating.again);
      expect(repo.logs.single.gradeSource, GradeSource.auto);
    });

    testWidgets('предложенная оценка выделена не только цветом', (
      tester,
    ) async {
      final repo = _Repo(contents: [_item('i1', _mcq('q1'))]);
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      // Предложена Good: галочка и подпись внутри кнопки.
      expect(
        find.descendant(
          of: _key('rating-good'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('rating-good'),
          matching: find.text('предложено'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('rating-hard'),
          matching: find.text('предложено'),
        ),
        findsNothing,
      );
    });
  });

  group('переопределение оценки (grade_source)', () {
    testWidgets('другая оценка, чем предложена, пишется как override', (
      tester,
    ) async {
      final repo = _Repo(contents: [_item('i1', _mcq('q1'))]);
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a')); // верно, предложена Good
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-hard'));
      await tester.pumpAndSettle();

      expect(repo.logs.single.rating, Rating.hard);
      expect(repo.logs.single.gradeSource, GradeSource.override);
    });

    testWidgets('тап по самой предложенной оценке — auto, не override', (
      tester,
    ) async {
      final repo = _Repo(contents: [_item('i1', _mcq('q1'))]);
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();

      expect(repo.logs.single.rating, Rating.good);
      expect(repo.logs.single.gradeSource, GradeSource.auto);
    });

    testWidgets(
      'при неверном ответе можно поставить Хорошо вопреки подсказке',
      (tester) async {
        final repo = _Repo(contents: [_item('i1', _mcq('q1'))]);
        await _pump(tester, repo, _MutableClock());
        await tester.tap(_key('mcq-option-b'));
        await tester.pumpAndSettle();
        await tester.tap(_key('rating-good'));
        await tester.pumpAndSettle();

        expect(repo.logs.single.rating, Rating.good);
        expect(repo.logs.single.gradeSource, GradeSource.override);
      },
    );
  });

  group('таймер', () {
    testWidgets('идёт по фейковым часам и обновляется раз в секунду', (
      tester,
    ) async {
      final repo = _threeItems();
      final clock = _MutableClock();
      await _pump(tester, repo, clock);
      expect(find.text('Осталось 5:00'), findsOneWidget);
      expect(
        tester.widget<LinearProgressIndicator>(_key('session-time-bar')).value,
        1.0,
      );

      clock.advance(const Duration(seconds: 90));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Осталось 3:30'), findsOneWidget);
      expect(
        tester.widget<LinearProgressIndicator>(_key('session-time-bar')).value,
        closeTo(210 / 300, 1e-9),
      );

      clock.advance(const Duration(seconds: 209));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Осталось 0:01'), findsOneWidget);
    });

    testWidgets('время вышло: текущий вопрос дописывается, затем итоги', (
      tester,
    ) async {
      final repo = _threeItems();
      final clock = _MutableClock();
      await _pump(tester, repo, clock);

      clock.advance(const Duration(minutes: 5, seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Время вышло: дайте ответ на этот вопрос'),
        findsOneWidget,
      );
      expect(
        tester.widget<LinearProgressIndicator>(_key('session-time-bar')).value,
        0.0,
      );
      // Вопрос ещё на экране, ответить можно.
      expect(find.text('Вопрос q1'), findsOneWidget);
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();

      expect(repo.logs, hasLength(1));
      // В очереди ещё два вопроса, но время вышло: сессия закончилась.
      expect(_key('session-summary-title'), findsOneWidget);
      expect(find.text('Повторено: 1'), findsOneWidget);
      expect(find.text('Вопрос q2'), findsNothing);
    });

    testWidgets('тикер отменяется при уходе с экрана (нет висящих таймеров)', (
      tester,
    ) async {
      final repo = _threeItems();
      final clock = _MutableClock();
      await _pump(tester, repo, clock);

      await tester.pumpWidget(const SizedBox());
      // Если бы Timer.periodic остался, testWidgets упал бы «Timer is still
      // pending», а setState после dispose бросил бы исключение.
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });
  });

  group('пустая очередь (ТЗ §8.5, AC3.3)', () {
    testWidgets('нет знаний: «К колодам»', (tester) async {
      await _pump(tester, _Repo(), _MutableClock());
      expect(_key('session-empty-title'), findsOneWidget);
      expect(find.text('Пока нечего повторять'), findsOneWidget);
      expect(find.text('Скачайте колоду, чтобы начать.'), findsOneWidget);
      expect(_key('session-take-new'), findsNothing);

      await tester.tap(_key('session-to-decks'));
      await tester.pumpAndSettle();
      expect(find.text('экран-колоды'), findsOneWidget);
    });

    testWidgets('всё повторено: «Следующее — через 3 ч», новых нет', (
      tester,
    ) async {
      final clock = _MutableClock();
      final repo = _Repo(
        contents: [_item('i1', _mcq('q1'))],
        states: {'i1': fakeState('i1', _t0.add(const Duration(hours: 3)))},
      );
      await _pump(tester, repo, clock);

      expect(find.text('Всё повторено 🎉'), findsOneWidget);
      expect(find.text('Следующее повторение — через 3 ч'), findsOneWidget);
      expect(_key('session-take-new'), findsNothing);
      expect(_key('session-time'), findsNothing);
      expect(repo.logs, isEmpty);

      await tester.tap(_key('session-home'));
      await tester.pumpAndSettle();
      expect(find.text('экран-главный'), findsOneWidget);
    });

    testWidgets('лимит новых исчерпан: «Взять 5 новых» запускает сессию', (
      tester,
    ) async {
      final repo = _Repo(
        contents: [_item('i1', _mcq('q1')), _item('i2', _mcq('q2'))],
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
      expect(
        find.text('На сегодня лимит новых знаний исчерпан.'),
        findsOneWidget,
      );
      expect(find.text('Взять 5 новых'), findsOneWidget);

      await tester.tap(_key('session-take-new'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 1 из 2'), findsOneWidget);
      expect(find.text('Вопрос q1'), findsOneWidget);
    });
  });

  group('ошибки (ТЗ §8.5)', () {
    testWidgets('ошибка записи: вопрос остаётся, можно повторить', (
      tester,
    ) async {
      final repo = _Repo(contents: [_item('i1', _mcq('q1'))])..failWrites = 1;
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();

      expect(
        find.text('Не удалось сохранить ответ. Нажмите оценку ещё раз.'),
        findsOneWidget,
      );
      expect(repo.logs, isEmpty);
      expect(find.text('Вопрос 1 из 1'), findsOneWidget);
      // Кнопки снова активны.
      expect(
        tester.widget<FilledButton>(_key('rating-next')).onPressed,
        isNotNull,
      );

      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();
      expect(repo.logs, hasLength(1));
      expect(_key('session-save-error'), findsNothing);
      expect(_key('session-summary-title'), findsOneWidget);
    });

    testWidgets('ошибка построения очереди: сообщение и «Повторить»', (
      tester,
    ) async {
      final repo = _Repo(contents: [_item('i1', _mcq('q1'))])..failReads = 1;
      await _pump(tester, repo, _MutableClock());

      expect(
        find.text('Не удалось подготовить сессию. Попробуйте ещё раз.'),
        findsOneWidget,
      );
      await tester.tap(_key('session-retry'));
      await tester.pumpAndSettle();
      expect(_key('session-start-error'), findsNothing);
      expect(find.text('Вопрос q1'), findsOneWidget);
    });

    testWidgets(
      'формат без модуля в реестре не показывается и не ломает сессию',
      (tester) async {
        // В очереди есть знание только с open: реестр его не поддерживает, поэтому
        // построитель пропускает знание, а mcq-знание идёт как обычно.
        final repo = _Repo(
          contents: [
            fakeContent(
              'i0',
              questions: [fakeQuestion('i0.open', QuestionType.open)],
            ),
            _item('i1', _mcq('q1')),
          ],
        );
        await _pump(tester, repo, _MutableClock());
        expect(find.text('Вопрос 1 из 1'), findsOneWidget);
        expect(find.text('Вопрос q1'), findsOneWidget);
      },
    );

    testWidgets('запасной экран: тип есть в очереди, но модуля нет', (
      tester,
    ) async {
      final repo = _Repo(contents: [_item('i1', _flip('q1'))]);
      await _pump(
        tester,
        repo,
        _MutableClock(),
        overrides: [
          // Очередь берёт flip, а реестр о нём «не знает».
          supportedQuestionTypesProvider.overrideWithValue({QuestionType.flip}),
          questionRegistryProvider.overrideWithValue(QuestionRegistry([])),
        ],
      );
      expect(_key('session-unsupported'), findsOneWidget);
      await tester.tap(find.text('Закончить сессию'));
      await tester.pumpAndSettle();
      expect(_key('session-summary-title'), findsOneWidget);
    });
  });

  group('выход и прерывание', () {
    testWidgets('крестик спрашивает подтверждение; «Остаться» возвращает', (
      tester,
    ) async {
      final repo = _threeItems();
      await _pump(tester, repo, _MutableClock());

      await tester.tap(_key('session-close'));
      await tester.pumpAndSettle();
      expect(find.text('Выйти из сессии?'), findsOneWidget);
      expect(find.text('Уже данные ответы сохранены.'), findsOneWidget);

      await tester.tap(_key('session-exit-stay'));
      await tester.pumpAndSettle();
      expect(find.text('Выйти из сессии?'), findsNothing);
      expect(find.text('Вопрос q1'), findsOneWidget);
    });

    testWidgets('«Выйти» уводит на главный; ответы уже в БД (AC3.2)', (
      tester,
    ) async {
      final repo = _threeItems();
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();

      await tester.tap(_key('session-close'));
      await tester.pumpAndSettle();
      await tester.tap(_key('session-exit-leave'));
      await tester.pumpAndSettle();

      expect(find.text('экран-главный'), findsOneWidget);
      expect(repo.logs, hasLength(1));
      expect(repo.states.keys, {'i1'});
    });

    testWidgets('системная кнопка «назад» тоже спрашивает подтверждение', (
      tester,
    ) async {
      final repo = _threeItems();
      await _pump(tester, repo, _MutableClock());

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Выйти из сессии?'), findsOneWidget);
      expect(find.text('Вопрос q1'), findsOneWidget);
    });

    testWidgets('на итогах крестик ведёт на главный без подтверждения', (
      tester,
    ) async {
      final repo = _Repo(contents: [_item('i1', _flip('q1'))]);
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('flip-show'));
      await tester.pumpAndSettle();
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();
      expect(_key('session-summary-title'), findsOneWidget);

      await tester.tap(_key('session-close'));
      await tester.pumpAndSettle();
      expect(find.text('Выйти из сессии?'), findsNothing);
      expect(find.text('экран-главный'), findsOneWidget);
    });
  });

  group('поворот экрана', () {
    testWidgets(
      'сессия, ответ и вердикт сохраняются; очередь не строится заново',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(400, 800);
        addTearDown(tester.view.reset);
        final repo = _threeItems();
        await _pump(tester, repo, _MutableClock());
        await tester.tap(_key('flip-show'));
        await tester.pumpAndSettle();
        await tester.tap(_key('rating-good'));
        await tester.pumpAndSettle();
        // Второй вопрос: отвечаем, оценку пока не ставим.
        await tester.tap(_key('mcq-option-b'));
        await tester.pumpAndSettle();
        expect(repo.queueBuilds, 1);

        tester.view.physicalSize = const Size(800, 400);
        await tester.pumpAndSettle();

        expect(find.text('Вопрос 2 из 3'), findsOneWidget);
        expect(_key('verdict-banner'), findsOneWidget);
        expect(find.text('Предложенная оценка: Снова'), findsOneWidget);
        expect(repo.queueBuilds, 1);
        expect(repo.logs, hasLength(1));

        // В альбомной ориентации панель оценки ниже экрана: прокручиваем.
        await tester.ensureVisible(_key('rating-next'));
        await tester.pumpAndSettle();
        await tester.tap(_key('rating-next'));
        await tester.pumpAndSettle();
        expect(repo.logs, hasLength(2));
        expect(find.text('Вопрос 3 из 3'), findsOneWidget);
      },
    );
  });

  group('доступность панели оценки', () {
    testWidgets('кнопки не меньше 48 dp и подписаны; предложенная названа', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = _Repo(contents: [_item('i1', _mcq('q1'))]);
      await _pump(tester, repo, _MutableClock());
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final rating in Rating.values) {
        expect(
          tester.getSize(_key('rating-${rating.name}')).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(
        tester.getSemantics(_key('rating-good')).label,
        'Хорошо, предложено',
      );
      expect(tester.getSemantics(_key('rating-hard')).label, 'Трудно');
      handle.dispose();
    });
  });
}
