// Жалоба и «не согласен» на экране сессии: drift в памяти и
// `content/decks/sample.json` (T20, M11, AC11.1, CLAUDE.md, правило 4).
// Жалоба пишется локально и сразу скрывает вопрос; «не согласен» — лог
// `override` и report одной транзакцией. Сеть не нужна: отправка — дело
// SyncService (test/core/sync/report_sync_test.dart).
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
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
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/presentation/session_screen.dart';
import 'package:mater_studorium/features/speech/data/speech_providers.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/deck_fixtures.dart';
import '../../../helpers/fake_open_services.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/session_db_fixtures.dart';
import '../../../helpers/unmount_app.dart';

const _mcq = 'infosec.xss.reflected.q1';
const _open = 'infosec.xss.reflected.q2';
const _answer =
    'Скрипт приходит в ссылке и возвращается в ответе без экранирования';

Finder _key(String k) => find.byKey(Key(k));

Future<AppDatabase> _seed({required bool openFirst}) async {
  final db = memoryDb();
  await db.decksDao.replaceDeck(
    Deck.fromJson(readJsonFile(sampleDeckPath)),
    downloadedAt: t0,
  );
  if (openFirst) {
    // Знание xss уже учили, стабильность выше порога для `open`: сессия
    // начинается с его `open` (как в session_open_drift_test).
    await answerItem(
      db,
      'infosec.xss.reflected',
      at: t0.subtract(const Duration(days: 4)),
      due: t0.subtract(const Duration(days: 1)),
      deckId: 'sample',
      questionId: _mcq,
    );
  }
  return db;
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db, {
  FakeGradingRepository? grading,
}) async {
  var ids = 0;
  await tester.pumpApp(
    const SessionScreen(),
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sessionUserIdProvider.overrideWithValue(() => sessionUser),
      clockProvider.overrideWithValue(() => t0),
      randomProvider.overrideWithValue(math.Random(1)),
      uuidGeneratorProvider.overrideWithValue(
        () => 'aaaaaaaa-0000-4000-8000-${(++ids).toString().padLeft(12, '0')}',
      ),
      if (grading != null) gradingRepositoryProvider.overrideWithValue(grading),
      speechServiceProvider.overrideWithValue(FakeSpeechService()),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _checkOpen(WidgetTester tester, AppDatabase db) async {
  await db.settingsDao.write('llm_consent', 'granted');
  await tester.enterText(_key('open-input'), _answer);
  await tester.pump();
  await tester.tap(_key('open-check'));
  await tester.pumpAndSettle();
}

Future<List<Map<String, dynamic>>> _queued(AppDatabase db) async => [
  for (final row in await db.select(db.outbox).get())
    jsonDecode(row.payloadJson) as Map<String, dynamic>,
];

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('«Пожаловаться» (M11, AC11.1)', () {
    testWidgets('причина и комментарий → очередь и скрытие у автора сразу; '
        'сессия не блокируется', (tester) async {
      final db = await _seed(openFirst: false);
      await _pump(tester, db);

      // Кнопки жалобы нет, пока вопрос не отвечен.
      expect(_key('report-button'), findsNothing);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(_key('report-button'));
      await tester.tap(_key('report-button'));
      await tester.pumpAndSettle();
      expect(find.text('На что пожаловаться?'), findsOneWidget);
      // Пять причин из M11; «Отправить» недоступна, пока причина не выбрана.
      for (final r in [
        'Неверный ответ',
        'Непонятно',
        'Опечатка',
        'Плохой источник',
        'Другое',
      ]) {
        expect(find.text(r), findsOneWidget);
      }
      expect(
        tester.widget<FilledButton>(_key('report-send')).onPressed,
        isNull,
      );

      await tester.tap(_key('report-reason-bad_source'));
      await tester.pump();
      await tester.enterText(
        _key('report-comment'),
        '  ссылка не открывается ',
      );
      await tester.tap(_key('report-send'));
      await tester.pumpAndSettle();

      // Подтверждение, кнопка стала «Жалоба отправлена» и недоступна.
      expect(find.textContaining('Спасибо'), findsOneWidget);
      expect(find.text('Жалоба отправлена'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_key('report-button')).onPressed,
        isNull,
      );

      // Локально: очередь и скрытие, всё под текущим пользователем.
      final queued = await _queued(db);
      expect(queued, [
        {
          'id': 'aaaaaaaa-0000-4000-8000-000000000001',
          'deck_id': 'sample',
          'deck_version': 1,
          'question_id': _mcq,
          'reason': 'bad_source',
          'comment': 'ссылка не открывается',
          'question_text':
              'Что отличает отражённую (reflected) XSS от хранимой (stored)?',
        },
      ]);
      expect((await db.select(db.outbox).getSingle()).userId, sessionUser);
      expect(await db.decksDao.hiddenQuestionIds(), {_mcq});

      // Сессия идёт как обычно: оценка записывается, следующий вопрос.
      await tester.ensureVisible(_key('rating-next'));
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 2 из 2'), findsOneWidget);
      expect(await db.select(db.reviewLogs).get(), hasLength(1));
      await tester.unmountApp();
    });

    testWidgets('«Отмена» ничего не пишет; без выбора причины не отправить', (
      tester,
    ) async {
      final db = await _seed(openFirst: false);
      await _pump(tester, db);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(_key('report-button'));
      await tester.tap(_key('report-button'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('report-comment'), 'текст без причины');
      await tester.tap(_key('report-cancel'));
      await tester.pumpAndSettle();

      expect(find.text('На что пожаловаться?'), findsNothing);
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(await db.decksDao.hiddenQuestionIds(), isEmpty);
      // Кнопка осталась доступной.
      expect(
        tester.widget<TextButton>(_key('report-button')).onPressed,
        isNotNull,
      );
      await tester.unmountApp();
    });

    testWidgets('ошибка локальной БД: сообщение, шторка открыта, можно '
        'повторить', (tester) async {
      final db = await _seed(openFirst: false);
      await _pump(tester, db);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();

      await db.customStatement('ALTER TABLE outbox RENAME TO outbox_off');
      await tester.ensureVisible(_key('report-button'));
      await tester.tap(_key('report-button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('report-reason-typo'));
      await tester.pump();
      await tester.tap(_key('report-send'));
      await tester.pumpAndSettle();

      expect(_key('report-error'), findsOneWidget);
      expect(find.text('На что пожаловаться?'), findsOneWidget);
      expect(await db.decksDao.hiddenQuestionIds(), isEmpty);

      await db.customStatement('ALTER TABLE outbox_off RENAME TO outbox');
      await tester.ensureVisible(_key('report-send'));
      await tester.tap(_key('report-send'));
      await tester.pumpAndSettle();
      expect(find.text('Жалоба отправлена'), findsOneWidget);
      expect(await _queued(db), hasLength(1));
      await tester.unmountApp();
    });

    testWidgets('скрытый вопрос не показывается в следующей сессии', (
      tester,
    ) async {
      final db = await _seed(openFirst: false);
      await _pump(tester, db);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('report-button'));
      await tester.tap(_key('report-button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('report-reason-wrong_answer'));
      await tester.pump();
      await tester.tap(_key('report-send'));
      await tester.pumpAndSettle();
      await tester.unmountApp();

      // Новая сессия на той же БД: у знания xss остаётся только open (mcq
      // скрыт), а знание hsts — flip; mcq xss среди вопросов нет.
      await _pump(tester, db);
      expect(
        find.text(
          'Что отличает отражённую (reflected) XSS от хранимой (stored)?',
        ),
        findsNothing,
      );
      await tester.unmountApp();
    });

    testWidgets('тап-цели кнопки и шторки не меньше 48 dp', (tester) async {
      final db = await _seed(openFirst: false);
      await _pump(tester, db);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('report-button'));
      expect(
        tester.getSize(_key('report-button')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(_key('report-button'));
      await tester.pumpAndSettle();
      for (final k in ['report-send', 'report-cancel']) {
        final size = tester.getSize(_key(k));
        expect(size.height, greaterThanOrEqualTo(48), reason: k);
        expect(size.width, greaterThanOrEqualTo(48), reason: k);
      }
      for (final r in [
        'wrong_answer',
        'unclear',
        'typo',
        'bad_source',
        'other',
      ]) {
        expect(
          tester.getSize(_key('report-reason-$r')).height,
          greaterThanOrEqualTo(48),
          reason: r,
        );
      }
      await tester.unmountApp();
    });
  });

  group('«Не согласен с оценкой» (M11)', () {
    testWidgets('своя оценка → лог override и report с ответом и вердиктом '
        'одним действием', (tester) async {
      final db = await _seed(openFirst: true);
      final grading = FakeGradingRepository([
        fakeGrade(verdict: GradeVerdict.partial, score: 0.5),
      ]);
      await _pump(tester, db, grading: grading);
      await _checkOpen(tester, db);

      expect(find.text('Почти верно'), findsOneWidget);
      await tester.ensureVisible(_key('disagree-button'));
      await tester.tap(_key('disagree-button'));
      await tester.pumpAndSettle();

      expect(find.text('Не согласен с оценкой ИИ'), findsOneWidget);
      expect(find.textContaining('«Почти верно»'), findsOneWidget);
      // Оценку, которую предложил ИИ (Трудно), выбрать нельзя: с ней спор.
      expect(_key('disagree-rating-hard'), findsNothing);
      for (final r in ['again', 'good', 'easy']) {
        expect(_key('disagree-rating-$r'), findsOneWidget);
      }
      // Без выбора оценки не отправить.
      expect(
        tester.widget<FilledButton>(_key('disagree-send')).onPressed,
        isNull,
      );

      await tester.tap(_key('disagree-rating-good'));
      await tester.pump();
      await tester.enterText(_key('disagree-comment'), 'я всё объяснил');
      await tester.tap(_key('disagree-send'));
      await tester.pumpAndSettle();

      // Лог: override и выбранная оценка, текст ответа и балл ИИ сохранены.
      final log = (await db.select(db.reviewLogs).get()).singleWhere(
        (l) => l.questionId == _open,
      );
      expect(log.gradeSource, 'override');
      expect(log.rating, Rating.good.code);
      expect(log.answerText, _answer);
      expect(log.llmScore, 0.5);
      // Report в очереди той же записью: ответ, вердикт, балл и оценка.
      expect(await _queued(db), [
        {
          'id': 'aaaaaaaa-0000-4000-8000-000000000002',
          'deck_id': 'sample',
          'deck_version': 1,
          'question_id': _open,
          'reason': 'grading_disagree',
          'comment': 'я всё объяснил',
          'question_text': 'Объясните, как работает отражённая XSS-атака и как от неё защищаются.',
          'answer_text': _answer,
          'llm_verdict': 'partial',
          'llm_score': 0.5,
          'user_rating': 3,
        },
      ]);
      // Вопрос при этом не скрывается: он в порядке, спорна лишь оценка.
      expect(await db.decksDao.hiddenQuestionIds(), isEmpty);
      // Состояние FSRS обновлено выбранной оценкой, сессия пошла дальше.
      expect(find.text('Вопрос 2 из 2'), findsOneWidget);
      expect(find.textContaining('Куратор посмотрит'), findsOneWidget);
      final state = (await db.select(db.userItemStates).get()).singleWhere(
        (s) => s.itemId == 'infosec.xss.reflected',
      );
      expect(state.dirty, isTrue);
      await tester.unmountApp();
    });

    testWidgets('закрыли шторку — ничего не записано, оценка не поставлена', (
      tester,
    ) async {
      final db = await _seed(openFirst: true);
      final grading = FakeGradingRepository([
        fakeGrade(verdict: GradeVerdict.incorrect, score: 0.1),
      ]);
      await _pump(tester, db, grading: grading);
      await _checkOpen(tester, db);

      await tester.ensureVisible(_key('disagree-button'));
      await tester.tap(_key('disagree-button'));
      await tester.pumpAndSettle();
      // Предложено «Снова»: его среди вариантов нет.
      expect(_key('disagree-rating-again'), findsNothing);
      await tester.tap(_key('disagree-cancel'));
      await tester.pumpAndSettle();

      expect(await db.select(db.outbox).get(), isEmpty);
      expect(
        (await db.select(db.reviewLogs).get()).where(
          (l) => l.questionId == _open,
        ),
        isEmpty,
      );
      // Обычная оценка по-прежнему работает (llm, без report).
      await tester.ensureVisible(_key('rating-next'));
      await tester.tap(_key('rating-next'));
      await tester.pumpAndSettle();
      final log = (await db.select(db.reviewLogs).get()).singleWhere(
        (l) => l.questionId == _open,
      );
      expect(log.gradeSource, 'llm');
      expect(await db.select(db.outbox).get(), isEmpty);
      await tester.unmountApp();
    });

    testWidgets('кнопки нет без вердикта ИИ: mcq, самооценка', (tester) async {
      // mcq.
      var db = await _seed(openFirst: false);
      await _pump(tester, db);
      await tester.tap(_key('mcq-option-a'));
      await tester.pumpAndSettle();
      expect(_key('disagree-button'), findsNothing);
      await tester.unmountApp();

      // open без сети: самооценка, вердикта ИИ нет.
      db = await _seed(openFirst: true);
      final grading = FakeGradingRepository([const NetworkError('нет сети')]);
      await _pump(tester, db, grading: grading);
      await _checkOpen(tester, db);
      await tester.ensureVisible(_key('open-self-assess'));
      await tester.tap(_key('open-self-assess'));
      await tester.pumpAndSettle();
      expect(_key('disagree-button'), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('ошибка записи: сообщение, шторка закрыта, можно повторить', (
      tester,
    ) async {
      final db = await _seed(openFirst: true);
      final grading = FakeGradingRepository([
        fakeGrade(verdict: GradeVerdict.correct, score: 0.9),
      ]);
      await _pump(tester, db, grading: grading);
      await _checkOpen(tester, db);

      await db.customStatement('ALTER TABLE outbox RENAME TO outbox_off');
      await tester.ensureVisible(_key('disagree-button'));
      await tester.tap(_key('disagree-button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('disagree-rating-easy'));
      await tester.pump();
      await tester.tap(_key('disagree-send'));
      await tester.pumpAndSettle();

      // Транзакция откатилась целиком: ни лога, ни состояния для open.
      expect(find.text('Вопрос 1 из 2'), findsOneWidget);
      expect(_key('session-save-error'), findsOneWidget);
      expect(
        (await db.select(db.reviewLogs).get()).where(
          (l) => l.questionId == _open,
        ),
        isEmpty,
      );

      await db.customStatement('ALTER TABLE outbox_off RENAME TO outbox');
      await tester.ensureVisible(_key('disagree-button'));
      await tester.tap(_key('disagree-button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('disagree-rating-easy'));
      await tester.pump();
      await tester.tap(_key('disagree-send'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 2 из 2'), findsOneWidget);
      expect(await _queued(db), hasLength(1));
      await tester.unmountApp();
    });

    testWidgets('тап-цели шторки не меньше 48 dp', (tester) async {
      final db = await _seed(openFirst: true);
      final grading = FakeGradingRepository([fakeGrade()]);
      await _pump(tester, db, grading: grading);
      await _checkOpen(tester, db);
      await tester.ensureVisible(_key('disagree-button'));
      expect(
        tester.getSize(_key('disagree-button')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(_key('disagree-button'));
      await tester.pumpAndSettle();
      for (final k in ['disagree-send', 'disagree-cancel']) {
        expect(
          tester.getSize(_key(k)).height,
          greaterThanOrEqualTo(48),
          reason: k,
        );
      }
      for (final r in ['again', 'good', 'easy']) {
        expect(
          tester.getSize(_key('disagree-rating-$r')).height,
          greaterThanOrEqualTo(48),
          reason: r,
        );
      }
      await tester.unmountApp();
    });
  });
}
