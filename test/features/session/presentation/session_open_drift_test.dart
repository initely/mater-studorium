// Экран сессии на drift в памяти и `content/decks/sample.json`: вопрос `open`
// проходится целиком, лог пишется с grade_source llm или self (T16, AC5.2,
// CLAUDE.md, правило 4). Оценка и диктовка — фейки; согласие — настоящее
// хранилище (`app_settings`).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/db/database_providers.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/grading/data/grading_providers.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:mater_studorium/features/questions/flip/flip_module.dart';
import 'package:mater_studorium/features/questions/mcq/mcq_module.dart';
import 'package:mater_studorium/features/questions/open/open_module.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/presentation/session_screen.dart';
import 'package:mater_studorium/features/speech/data/speech_providers.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/deck_fixtures.dart';
import '../../../helpers/fake_open_services.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sample_formats.dart';
import '../../../helpers/session_db_fixtures.dart';
import '../../../helpers/unmount_app.dart';

const _openQuestion = 'infosec.xss.reflected.q2';
const _answer =
    'Скрипт приходит в ссылке и возвращается в ответе без экранирования';

Future<AppDatabase> _seed(WidgetTester tester) async {
  final db = memoryDb();
  await db.decksDao.replaceDeck(
    Deck.fromJson(readJsonFile(sampleDeckPath)),
    downloadedAt: t0,
  );
  // Знание xss уже учили: стабильность выше порога для `open` (3 дня), прошлый
  // вариант — mcq, срок вышел. Поэтому сессия начинается с его `open`.
  await answerItem(
    db,
    'infosec.xss.reflected',
    at: t0.subtract(const Duration(days: 4)),
    due: t0.subtract(const Duration(days: 1)),
    deckId: 'sample',
    questionId: 'infosec.xss.reflected.q1',
  );
  return db;
}

Future<void> _pumpSession(
  WidgetTester tester,
  AppDatabase db,
  FakeGradingRepository grading,
) async {
  var ids = 0;
  await tester.pumpApp(
    const SessionScreen(),
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sessionUserIdProvider.overrideWithValue(() => sessionUser),
      clockProvider.overrideWithValue(() => t0),
      randomProvider.overrideWithValue(math.Random(1)),
      uuidGeneratorProvider.overrideWithValue(() => 'log-${ids++}'),
      gradingRepositoryProvider.overrideWithValue(grading),
      speechServiceProvider.overrideWithValue(FakeSpeechService()),
      ...registryOverrides(const [McqModule(), FlipModule(), OpenModule()]),
    ],
  );
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(Key(k));

void main() {
  testWidgets('open: оценка модели → вердикт, панель, лог grade_source = llm', (
    tester,
  ) async {
    final db = await _seed(tester);
    final grading = FakeGradingRepository([
      fakeGrade(verdict: GradeVerdict.correct, score: 0.85, missed: const []),
    ]);
    await _pumpSession(tester, db, grading);

    expect(find.text('Вопрос 1 из 2'), findsOneWidget);
    expect(
      find.text(
        'Объясните, как работает отражённая XSS-атака и как от неё защищаются.',
      ),
      findsOneWidget,
    );

    await tester.enterText(_key('open-input'), _answer);
    await tester.pump();
    await tester.tap(_key('open-check'));
    await tester.pumpAndSettle();

    // Первый `open`: диалог согласия, выбор запоминается в `app_settings`.
    expect(find.text('Проверка ответов моделью'), findsOneWidget);
    await tester.tap(_key('open-consent-allow'));
    await tester.pumpAndSettle();

    // Запрос по контракту: колода, версия, вопрос, ответ, режим.
    final req = grading.requests.single;
    expect(
      (req.deckId, req.deckVersion, req.questionId),
      ('sample', 1, _openQuestion),
    );
    expect(req.answerText, _answer);
    expect(req.inputMode.wire, 'text');

    // Вердикт и эталон из колоды; панели оценки нет, оценка Good выведена сама.
    expect(_key('verdict-banner'), findsOneWidget);
    expect(find.text('Верно'), findsOneWidget);
    expect(_key('rating-good'), findsNothing);
    expect(_key('rating-again'), findsNothing);
    expect(
      find.textContaining('Злоумышленник передаёт скрипт'),
      findsOneWidget,
    );
    expect(
      await db.settingsDao.readAll(),
      containsPair('llm_consent', 'granted'),
    );

    await tester.ensureVisible(_key('rating-next'));
    await tester.tap(_key('rating-next'));
    await tester.pumpAndSettle();

    final log = (await db.select(db.reviewLogs).get()).singleWhere(
      (l) => l.questionId == _openQuestion,
    );
    expect(log.gradeSource, 'llm');
    expect(log.rating, Rating.good.code);
    expect(log.llmScore, 0.85);
    expect(log.answerText, _answer);
    expect(log.questionType, 'open');

    // Сессия идёт дальше: следующий вопрос (flip).
    expect(find.text('Вопрос 2 из 2'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('open: оценка недоступна → самооценка, лог grade_source = self', (
    tester,
  ) async {
    final db = await _seed(tester);
    // Согласие уже есть: диалога нет.
    await db.settingsDao.write('llm_consent', 'granted');
    final grading = FakeGradingRepository([const NetworkError('нет сети')]);
    await _pumpSession(tester, db, grading);

    await tester.enterText(_key('open-input'), _answer);
    await tester.pump();
    await tester.tap(_key('open-check'));
    await tester.pumpAndSettle();

    // Сообщение без технических деталей, эталон, повтор и самооценка;
    // панель оценки ещё не показана.
    expect(find.textContaining('Проверка недоступна'), findsOneWidget);
    expect(
      find.textContaining('Злоумышленник передаёт скрипт'),
      findsOneWidget,
    );
    expect(_key('open-retry'), findsOneWidget);
    expect(_key('rating-good'), findsNothing);

    await tester.ensureVisible(_key('open-self-assess'));
    await tester.tap(_key('open-self-assess'));
    await tester.pumpAndSettle();

    // Вердикта нет, оценивает пользователь двумя кнопками.
    expect(_key('verdict-banner'), findsNothing);
    expect(find.text('Как хорошо вы это помнили?'), findsOneWidget);
    expect(_key('rating-next'), findsNothing);
    expect(_key('rating-hard'), findsNothing);
    expect(_key('rating-easy'), findsNothing);
    await tester.ensureVisible(_key('rating-good'));
    await tester.tap(_key('rating-good'));
    await tester.pumpAndSettle();

    final log = (await db.select(db.reviewLogs).get()).singleWhere(
      (l) => l.questionId == _openQuestion,
    );
    expect(log.gradeSource, 'self');
    expect(log.rating, Rating.good.code);
    expect(log.llmScore, isNull);
    expect(log.answerText, _answer);
    expect(find.text('Вопрос 2 из 2'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('open: квота исчерпана → самооценка без блокировки сессии', (
    tester,
  ) async {
    final db = await _seed(tester);
    await db.settingsDao.write('llm_consent', 'granted');
    final grading = FakeGradingRepository([
      QuotaExceededError('429', resetAt: DateTime.utc(2026, 10, 12)),
    ]);
    await _pumpSession(tester, db, grading);

    await tester.enterText(_key('open-input'), _answer);
    await tester.pump();
    await tester.tap(_key('open-check'));
    await tester.pumpAndSettle();

    expect(find.textContaining('проверки закончились'), findsOneWidget);
    // Повтора нет: панель оценки уже на экране.
    expect(_key('open-retry'), findsNothing);
    await tester.ensureVisible(_key('rating-again'));
    await tester.tap(_key('rating-again'));
    await tester.pumpAndSettle();

    final log = (await db.select(db.reviewLogs).get()).singleWhere(
      (l) => l.questionId == _openQuestion,
    );
    expect(log.gradeSource, 'self');
    expect(log.rating, Rating.again.code);
    await tester.unmountApp();
  });

  for (final c in [
    (GradeVerdict.partial, Rating.hard, 'Почти верно', 0.5),
    (GradeVerdict.incorrect, Rating.again, 'Неверно', 0.1),
  ]) {
    testWidgets(
      'open: вердикт ${c.$1.name} → без панели, «Дальше» пишет ${c.$2.name}, llm',
      (tester) async {
        final db = await _seed(tester);
        await db.settingsDao.write('llm_consent', 'granted');
        final grading = FakeGradingRepository([
          fakeGrade(verdict: c.$1, score: c.$4),
        ]);
        await _pumpSession(tester, db, grading);

        await tester.enterText(_key('open-input'), _answer);
        await tester.pump();
        await tester.tap(_key('open-check'));
        await tester.pumpAndSettle();
        expect(find.text(c.$3), findsWidgets);
        expect(_key('rating-again'), findsNothing);
        expect(_key('rating-good'), findsNothing);

        await tester.ensureVisible(_key('rating-next'));
        await tester.tap(_key('rating-next'));
        await tester.pumpAndSettle();

        final log = (await db.select(db.reviewLogs).get()).singleWhere(
          (l) => l.questionId == _openQuestion,
        );
        expect(log.gradeSource, 'llm');
        expect(log.rating, c.$2.code);
        expect(log.llmScore, c.$4);
        await tester.unmountApp();
      },
    );
  }

  group('open: самооценка двумя кнопками (grade_source = self)', () {
    Future<AppDatabase> toSelfAssess(
      WidgetTester tester,
      FakeGradingRepository grading,
    ) async {
      final db = await _seed(tester);
      await db.settingsDao.write('llm_consent', 'granted');
      await _pumpSession(tester, db, grading);
      await tester.enterText(_key('open-input'), _answer);
      await tester.pump();
      await tester.tap(_key('open-check'));
      await tester.pumpAndSettle();
      return db;
    }

    Future<void> expectSelfLog(AppDatabase db, Rating rating) async {
      final log = (await db.select(db.reviewLogs).get()).singleWhere(
        (l) => l.questionId == _openQuestion,
      );
      expect(log.gradeSource, 'self');
      expect(log.rating, rating.code);
      expect(log.llmScore, isNull);
    }

    testWidgets('модель не уверена (unsure) → «Не помню»', (tester) async {
      final db = await toSelfAssess(
        tester,
        FakeGradingRepository([fakeGrade(verdict: GradeVerdict.unsure)]),
      );
      expect(_key('rating-next'), findsNothing);
      await tester.ensureVisible(_key('rating-again'));
      await tester.tap(_key('rating-again'));
      await tester.pumpAndSettle();
      await expectSelfLog(db, Rating.again);
      await tester.unmountApp();
    });

    testWidgets('ошибка сервера → «Помню»', (tester) async {
      final db = await toSelfAssess(
        tester,
        FakeGradingRepository([const UnexpectedError('500')]),
      );
      expect(_key('rating-next'), findsNothing);
      await tester.ensureVisible(_key('rating-good'));
      await tester.tap(_key('rating-good'));
      await tester.pumpAndSettle();
      await expectSelfLog(db, Rating.good);
      await tester.unmountApp();
    });

    testWidgets('«Не помню» без ответа → две кнопки, self', (tester) async {
      final db = await _seed(tester);
      await _pumpSession(tester, db, FakeGradingRepository([]));
      await tester.ensureVisible(_key('open-skip'));
      await tester.tap(_key('open-skip'));
      await tester.pumpAndSettle();

      expect(_key('rating-next'), findsNothing);
      expect(_key('rating-hard'), findsNothing);
      expect(_key('rating-easy'), findsNothing);
      await tester.ensureVisible(_key('rating-again'));
      await tester.tap(_key('rating-again'));
      await tester.pumpAndSettle();
      await expectSelfLog(db, Rating.again);
      await tester.unmountApp();
    });
  });
}
