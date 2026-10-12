// Виджет `open` (T16): ввод, проверка, вердикт и разбор, каждое состояние
// ошибки с переходом на самооценку, двойной тап, поворот, диктовка на fake.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/data/catalog_providers.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/grading/data/grading_providers.dart';
import 'package:mater_studorium/features/grading/domain/grading_repository.dart';
import 'package:mater_studorium/features/grading/domain/llm_consent.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:mater_studorium/features/questions/open/open_module.dart';
import 'package:mater_studorium/features/questions/question_request.dart';
import 'package:mater_studorium/features/questions/question_result.dart';
import 'package:mater_studorium/features/speech/data/speech_providers.dart';
import 'package:mater_studorium/features/speech/domain/speech_service.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

import '../../../helpers/fake_open_services.dart';
import '../../../helpers/pump_app.dart';

const _reference =
    'Скрипт приходит в запросе и возвращается без экранирования.';

final _question = Question(
  id: 'infosec.xss.reflected.q2',
  type: QuestionType.open,
  prompt: 'Объясните отражённую XSS.',
  payload: const QuestionPayload.open(
    referenceAnswer: _reference,
    rubric: [
      RubricPoint(
        id: 'p1',
        text: 'Скрипт из запроса (локально)',
        weight: 3,
        required: true,
      ),
      RubricPoint(
        id: 'p2',
        text: 'Выполняется у жертвы (локально)',
        weight: 2,
        required: false,
      ),
      RubricPoint(
        id: 'p3',
        text: 'Защита: экранирование (локально)',
        weight: 2,
        required: true,
      ),
    ],
  ),
);

Finder _key(String k) => find.byKey(Key(k));

class _Harness {
  _Harness({
    FakeGradingRepository? grading,
    FakeSpeechService? speech,
    FakeLlmConsentRepository? consent,
    FakeAppSettingsOpener? opener,
    this.lang = 'ru',
  }) : grading = grading ?? FakeGradingRepository(),
       speech = speech ?? FakeSpeechService(),
       consent = consent ?? FakeLlmConsentRepository(LlmConsent.granted),
       opener = opener ?? FakeAppSettingsOpener();

  final FakeGradingRepository grading;
  final FakeSpeechService speech;
  final FakeLlmConsentRepository consent;
  final FakeAppSettingsOpener opener;
  final String lang;
  final answers = <QuestionResult>[];

  List<Override> get overrides => [
    gradingRepositoryProvider.overrideWithValue(grading),
    speechServiceProvider.overrideWithValue(speech),
    llmConsentRepositoryProvider.overrideWithValue(consent),
    appSettingsOpenerProvider.overrideWithValue(opener),
    deckLangProvider.overrideWith((ref, deckId) async => lang),
  ];

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(
      Scaffold(
        body: Builder(
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: const OpenModule().build(
              context,
              QuestionRequest(
                question: _question,
                shuffleSeed: 1,
                onAnswered: answers.add,
                deckId: 'sample',
                deckVersion: 1,
              ),
            ),
          ),
        ),
      ),
      overrides: overrides,
    );
    await tester.pump();
  }
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_key('open-input'), text);
  await tester.pump();
}

Future<void> _check(WidgetTester tester) async {
  await tester.ensureVisible(_key('open-check'));
  await tester.tap(_key('open-check'));
  await tester.pump();
  await tester.pump();
}

void _background(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void _foreground(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

const _answer = 'Скрипт из ссылки отражается в ответе без экранирования';

void main() {
  group('успешная проверка', () {
    testWidgets(
      'partial: разбор с сервера, эталон, квота, запрос по контракту',
      (tester) async {
        final h = _Harness(grading: FakeGradingRepository([fakeGrade()]));
        await h.pump(tester);
        expect(find.text('Объясните отражённую XSS.'), findsOneWidget);

        await _type(tester, _answer);
        await _check(tester);

        expect(h.grading.calls, 1);
        final req = h.grading.requests.single;
        expect(req.deckId, 'sample');
        expect(req.deckVersion, 1);
        expect(req.questionId, 'infosec.xss.reflected.q2');
        expect(req.answerText, _answer);
        expect(req.inputMode, AnswerInputMode.text);

        expect(h.answers, hasLength(1));
        expect(h.answers.single.outcome, AnswerOutcome.llmPartial);
        expect(h.answers.single.answerText, _answer);
        expect(h.answers.single.llmScore, 0.5);

        // Упущенное и комментарий — тексты с сервера; раскрытое — из локальной
        // рубрики; эталон — из колоды.
        expect(
          find.textContaining('Защита: экранирование вывода (сервер)'),
          findsOneWidget,
        );
        expect(find.textContaining('обязательный пункт'), findsOneWidget);
        expect(find.text('Скрипт из запроса (локально)'), findsOneWidget);
        expect(find.textContaining('Не объяснено'), findsOneWidget);
        expect(find.text(_reference), findsOneWidget);
        expect(find.text('Осталось 27 проверок на сегодня'), findsOneWidget);
        // Ввод заблокирован, повторно не проверить.
        expect(_key('open-check'), findsNothing);
        expect(tester.widget<TextField>(_key('open-input')).readOnly, isTrue);
      },
    );

    testWidgets('значки ✓ ½ ✗ не только цветом: у каждой строки есть озвучка', (
      tester,
    ) async {
      final h = _Harness(grading: FakeGradingRepository([fakeGrade()]));
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.timelapse), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^раскрыт: Скрипт из запроса')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^не раскрыт: Защита')),
        findsOneWidget,
      );
    });

    testWidgets('correct и incorrect → llmCorrect и llmIncorrect', (
      tester,
    ) async {
      for (final (verdict, outcome) in [
        (GradeVerdict.correct, AnswerOutcome.llmCorrect),
        (GradeVerdict.incorrect, AnswerOutcome.llmIncorrect),
      ]) {
        final h = _Harness(
          grading: FakeGradingRepository([
            fakeGrade(
              verdict: verdict,
              score: 0.9,
              feedback: '',
              missed: const [],
            ),
          ]),
        );
        await h.pump(tester);
        await _type(tester, _answer);
        await _check(tester);
        expect(h.answers.single.outcome, outcome);
        expect(h.answers.single.llmScore, 0.9);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('unsure — самооценка с эталоном, без блокировки', (
      tester,
    ) async {
      final h = _Harness(
        grading: FakeGradingRepository([
          fakeGrade(verdict: GradeVerdict.unsure, score: 0),
        ]),
      );
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);

      expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
      expect(h.answers.single.llmScore, isNull);
      expect(h.answers.single.answerText, _answer);
      expect(_key('open-fallback-message'), findsOneWidget);
      expect(
        find.textContaining('Не удалось уверенно оценить'),
        findsOneWidget,
      );
      expect(find.text(_reference), findsOneWidget);
      expect(_key('open-retry'), findsNothing);
    });

    testWidgets('сервер применил правило (source: rule) → autoIncorrect', (
      tester,
    ) async {
      final h2 = _Harness(
        grading: FakeGradingRepository([
          fakeGrade(
            verdict: GradeVerdict.incorrect,
            score: 0,
            origin: GradeOrigin.rule,
            points: const [],
            missed: const [],
            feedback: '',
            remainingQuota: null,
          ),
        ]),
      );
      await h2.pump(tester);
      await _type(tester, 'a​​​');
      await _check(tester);
      // Невидимые символы клиент не считает «пустыми»: решает сервер.
      expect(h2.grading.calls, 1);
      expect(h2.answers.single.outcome, AnswerOutcome.autoIncorrect);
      expect(h2.answers.single.llmScore, isNull);
      expect(_key('open-quota'), findsNothing);
    });
  });

  group('короткий и пустой ответ', () {
    testWidgets('пусто: «Проверить» выключена', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(tester.widget<FilledButton>(_key('open-check')).onPressed, isNull);
      await _type(tester, '   ');
      expect(tester.widget<FilledButton>(_key('open-check')).onPressed, isNull);
      await _type(tester, 'да');
      expect(
        tester.widget<FilledButton>(_key('open-check')).onPressed,
        isNotNull,
      );
    });

    testWidgets('1–2 символа: правило сервера локально, без запроса', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await _type(tester, 'да');
      await _check(tester);

      expect(h.grading.calls, 0);
      expect(h.consent.saves, 0);
      expect(h.answers.single.outcome, AnswerOutcome.autoIncorrect);
      expect(h.answers.single.answerText, 'да');
      expect(find.text(_reference), findsOneWidget);
    });

    testWidgets('«Не помню»: эталон и самооценка без запроса', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(_key('open-skip'));
      await tester.pump();

      expect(h.grading.calls, 0);
      expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
      expect(h.answers.single.answerText, isNull);
      expect(find.textContaining('Сравните ответ с эталоном'), findsOneWidget);
      expect(find.text(_reference), findsOneWidget);
    });
  });

  group('согласие на проверку внешней моделью', () {
    testWidgets('первый раз — диалог; «Разрешить» запоминается', (
      tester,
    ) async {
      final h = _Harness(
        consent: FakeLlmConsentRepository(),
        grading: FakeGradingRepository([fakeGrade()]),
      );
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);

      expect(find.text('Проверка ответов моделью'), findsOneWidget);
      expect(h.grading.calls, 0);
      await tester.tap(_key('open-consent-allow'));
      await tester.pump();
      await tester.pump();

      expect(h.consent.value, LlmConsent.granted);
      expect(h.grading.calls, 1);
      expect(h.answers.single.outcome, AnswerOutcome.llmPartial);
    });

    testWidgets('«Без ИИ»: ответ не уходит, самооценка, выбор запомнен', (
      tester,
    ) async {
      final h = _Harness(consent: FakeLlmConsentRepository());
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);
      await tester.tap(_key('open-consent-decline'));
      await tester.pump();
      await tester.pump();

      expect(h.consent.value, LlmConsent.declined);
      expect(h.grading.calls, 0);
      expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
      expect(find.textContaining('Проверка моделью выключена'), findsOneWidget);
      expect(find.text(_reference), findsOneWidget);
      expect(_key('open-retry'), findsNothing);
    });

    testWidgets('уже отказано — без диалога и без запроса', (tester) async {
      final h = _Harness(
        consent: FakeLlmConsentRepository(LlmConsent.declined),
      );
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);
      expect(find.text('Проверка ответов моделью'), findsNothing);
      expect(h.grading.calls, 0);
      expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
    });

    testWidgets('согласие уже есть — диалога нет', (tester) async {
      final h = _Harness(grading: FakeGradingRepository([fakeGrade()]));
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);
      expect(find.text('Проверка ответов моделью'), findsNothing);
      expect(h.grading.calls, 1);
    });
  });

  group('фолбэк на самооценку: оценка недоступна', () {
    Future<_Harness> failWith(WidgetTester tester, Object error) async {
      final h = _Harness(grading: FakeGradingRepository([error]));
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);
      return h;
    }

    testWidgets(
      'нет сети: сообщение, эталон, «Проверить ещё раз» и «Оценить самому»',
      (tester) async {
        final h = await failWith(tester, const NetworkError('нет сети'));
        expect(find.textContaining('Проверка недоступна'), findsOneWidget);
        expect(find.text(_reference), findsOneWidget);
        expect(_key('open-retry'), findsOneWidget);
        expect(_key('open-self-assess'), findsOneWidget);
        // Ответ ещё не отдан сессии: пользователь может повторить.
        expect(h.answers, isEmpty);
        // Технических деталей нет.
        expect(find.textContaining('NetworkError'), findsNothing);
        expect(find.textContaining('нет сети'), findsNothing);
      },
    );

    testWidgets(
      '«Оценить самому» после сбоя → llmUnavailable (grade_source self)',
      (tester) async {
        final h = await failWith(tester, const NetworkError('x'));
        await tester.ensureVisible(_key('open-self-assess'));
        await tester.tap(_key('open-self-assess'));
        await tester.pump();
        expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
        expect(h.answers.single.answerText, _answer);
        expect(_key('open-self-assess'), findsNothing);
        expect(_key('open-retry'), findsNothing);
      },
    );

    testWidgets('«Проверить ещё раз» после сбоя сети → оценка модели', (
      tester,
    ) async {
      final h = await failWith(tester, const NetworkError('x'));
      h.grading.enqueue(fakeGrade(verdict: GradeVerdict.correct, score: 0.8));
      await tester.ensureVisible(_key('open-retry'));
      await tester.tap(_key('open-retry'));
      await tester.pump();
      await tester.pump();

      expect(h.grading.calls, 2);
      expect(h.answers.single.outcome, AnswerOutcome.llmCorrect);
      expect(_key('open-fallback-message'), findsNothing);
      expect(_key('open-retry'), findsNothing);
    });

    testWidgets('повторный сбой: снова можно повторить или оценить себя', (
      tester,
    ) async {
      final h = await failWith(tester, const NetworkError('x'));
      h.grading.enqueue(const NetworkError('y'));
      await tester.ensureVisible(_key('open-retry'));
      await tester.tap(_key('open-retry'));
      await tester.pump();
      await tester.pump();
      expect(h.grading.calls, 2);
      expect(h.answers, isEmpty);
      expect(_key('open-retry'), findsOneWidget);
      expect(_key('open-self-assess'), findsOneWidget);
    });

    testWidgets(
      'квота исчерпана: сообщение с временем сброса, сразу самооценка',
      (tester) async {
        final reset = DateTime.utc(2026, 10, 13, 5, 7);
        final h = await failWith(
          tester,
          QuotaExceededError('429', resetAt: reset),
        );
        final local = reset.toLocal();
        final hhmm =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        expect(find.textContaining('обновятся в $hhmm'), findsOneWidget);
        expect(find.text(_reference), findsOneWidget);
        expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
        expect(_key('open-retry'), findsNothing);
        expect(_key('open-self-assess'), findsNothing);
      },
    );

    testWidgets('квота без времени сброса', (tester) async {
      final h = await failWith(tester, const QuotaExceededError('429'));
      expect(find.textContaining('проверки закончились'), findsOneWidget);
      expect(find.textContaining('обновятся'), findsNothing);
      expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
    });

    testWidgets('не вошёл (401): самооценка без повтора', (tester) async {
      final h = await failWith(tester, const AuthError('401'));
      expect(find.textContaining('нужно войти'), findsOneWidget);
      expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
      expect(_key('open-retry'), findsNothing);
    });

    testWidgets(
      'запрос отклонён или ответ не по контракту: «недоступна», без повтора',
      (tester) async {
        for (final error in [
          const RequestRejectedError('400', status: 400, code: 'unknown_field'),
          const UnexpectedError('мусор'),
        ]) {
          final h = await failWith(tester, error);
          expect(find.textContaining('Проверка недоступна'), findsOneWidget);
          expect(h.answers.single.outcome, AnswerOutcome.llmUnavailable);
          expect(_key('open-retry'), findsNothing);
          expect(find.textContaining('unknown_field'), findsNothing);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  });

  group('идемпотентность и устойчивость', () {
    testWidgets('двойной тап по «Проверить» шлёт один запрос', (tester) async {
      final gate = Completer<void>();
      final grading = FakeGradingRepository([fakeGrade()])..gate = gate;
      final h = _Harness(grading: grading);
      await h.pump(tester);
      await _type(tester, _answer);
      await tester.ensureVisible(_key('open-check'));

      // Два тапа подряд, между ними кадр не перерисован.
      await tester.tap(_key('open-check'));
      await tester.tap(_key('open-check'));
      await tester.pump();
      await tester.pump();
      expect(_key('open-checking'), findsOneWidget);
      expect(find.text('Проверяю…'), findsOneWidget);
      expect(grading.calls, 1);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(grading.calls, 1);
      expect(h.answers, hasLength(1));
    });

    testWidgets('пока открыт диалог согласия, второй диалог не открывается', (
      tester,
    ) async {
      final h = _Harness(
        consent: FakeLlmConsentRepository(),
        grading: FakeGradingRepository([fakeGrade()]),
      );
      await h.pump(tester);
      await _type(tester, _answer);
      await tester.ensureVisible(_key('open-check'));
      await tester.tap(_key('open-check'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Проверка ответов моделью'), findsOneWidget);
      await tester.tap(_key('open-check'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Проверка ответов моделью'), findsOneWidget);
      await tester.tap(_key('open-consent-allow'));
      await tester.pump();
      await tester.pump();
      expect(h.grading.calls, 1);
    });

    testWidgets('«Проверить ещё раз» двойным тапом — один повторный запрос', (
      tester,
    ) async {
      final h = _Harness(
        grading: FakeGradingRepository([const NetworkError('x')]),
      );
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);
      h.grading.gate = Completer<void>();
      h.grading.enqueue(fakeGrade());
      await tester.ensureVisible(_key('open-retry'));
      await tester.tap(_key('open-retry'));
      await tester.tap(_key('open-retry'));
      await tester.pump();
      expect(h.grading.calls, 2);
      h.grading.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(h.grading.calls, 2);
    });

    testWidgets('поворот экрана: текст и идущая проверка не теряются', (
      tester,
    ) async {
      final gate = Completer<void>();
      final grading = FakeGradingRepository([fakeGrade()])..gate = gate;
      final h = _Harness(grading: grading);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await h.pump(tester);
      await _type(tester, _answer);

      // Поворот до проверки: текст на месте.
      tester.view.physicalSize = const Size(1600, 800);
      await tester.pump();
      expect(
        tester.widget<TextField>(_key('open-input')).controller!.text,
        _answer,
      );

      await _check(tester);
      // Поворот во время проверки: запрос не прерывается и не повторяется.
      tester.view.physicalSize = const Size(800, 1600);
      await tester.pump();
      expect(_key('open-checking'), findsOneWidget);
      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(grading.calls, 1);
      expect(h.answers.single.outcome, AnswerOutcome.llmPartial);
      expect(h.answers.single.answerText, _answer);
    });

    testWidgets('уход в фон и возврат во время проверки: ответ приходит', (
      tester,
    ) async {
      final gate = Completer<void>();
      final grading = FakeGradingRepository([fakeGrade()])..gate = gate;
      final h = _Harness(grading: grading);
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);

      _background(tester);
      await tester.pump();
      _foreground(tester);
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(grading.calls, 1);
      expect(h.answers, hasLength(1));
      expect(find.text(_reference), findsOneWidget);
    });
  });

  group('лимит длины', () {
    testWidgets('счётчик и обрезка до 2000 единиц UTF-16', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(find.text('0 из 2000'), findsOneWidget);
      await _type(tester, 'а' * 2100);
      expect(find.text('2000 из 2000'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('open-input')).controller!.text.length,
        2000,
      );
    });

    testWidgets('эмодзи считаются как две единицы, пара не рвётся', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await _type(tester, '😀' * 1001);
      final text = tester
          .widget<TextField>(_key('open-input'))
          .controller!
          .text;
      expect(text.length, 2000);
      expect(text.runes.length, 1000);
    });
  });

  group('диктовка', () {
    testWidgets('успех: текст появляется в поле, правится, уходит как voice', (
      tester,
    ) async {
      final h = _Harness(grading: FakeGradingRepository([fakeGrade()]));
      await h.pump(tester);
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();

      expect(h.speech.listens, 1);
      expect(h.speech.lastLang, 'ru');
      expect(_key('open-mic-listening'), findsOneWidget);
      // Поле во время диктовки только для чтения.
      expect(tester.widget<TextField>(_key('open-input')).readOnly, isTrue);

      h.speech.say('скрипт из');
      await tester.pump();
      expect(find.text('скрипт из'), findsOneWidget);
      h.speech.say('скрипт из ссылки', isFinal: true);
      await tester.pump();
      expect(
        tester.widget<TextField>(_key('open-input')).controller!.text,
        'скрипт из ссылки',
      );

      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      expect(h.speech.stops, 1);
      expect(_key('open-mic-listening'), findsNothing);
      expect(
        find.text('Распознанный текст можно поправить перед проверкой.'),
        findsOneWidget,
      );

      // Правка перед отправкой.
      await _type(tester, 'скрипт из ссылки отражается без экранирования');
      await _check(tester);

      expect(h.grading.requests.single.inputMode, AnswerInputMode.voice);
      expect(
        h.grading.requests.single.answerText,
        'скрипт из ссылки отражается без экранирования',
      );
    });

    testWidgets('диктовка добавляется к уже набранному тексту', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await _type(tester, 'Сначала набрал.');
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      h.speech.say('потом сказал');
      await tester.pump();
      expect(
        tester.widget<TextField>(_key('open-input')).controller!.text,
        'Сначала набрал. потом сказал',
      );
    });

    testWidgets('печать без диктовки — input_mode text', (tester) async {
      final h = _Harness(grading: FakeGradingRepository([fakeGrade()]));
      await h.pump(tester);
      await _type(tester, _answer);
      await _check(tester);
      expect(h.grading.requests.single.inputMode, AnswerInputMode.text);
    });

    testWidgets('диктовку стёрли целиком — снова text', (tester) async {
      final h = _Harness(grading: FakeGradingRepository([fakeGrade()]));
      await h.pump(tester);
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      h.speech.say('что-то сказал');
      await tester.pump();
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      await _type(tester, '');
      await _type(tester, _answer);
      await _check(tester);
      expect(h.grading.requests.single.inputMode, AnswerInputMode.text);
    });

    testWidgets('«Отмена» возвращает текст, который был до диктовки', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await _type(tester, 'Было.');
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      h.speech.say('лишнее');
      await tester.pump();
      await tester.tap(_key('open-mic-cancel'));
      await tester.pump();
      await tester.pump();

      expect(h.speech.cancels, 1);
      expect(_key('open-mic-listening'), findsNothing);
      expect(
        tester.widget<TextField>(_key('open-input')).controller!.text,
        'Было.',
      );
      expect(tester.widget<TextField>(_key('open-input')).readOnly, isFalse);
    });

    testWidgets('двойной тап по микрофону открывает одну сессию', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(_key('open-mic'));
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      expect(h.speech.listens, 1);
    });

    testWidgets(
      '«Проверить» во время диктовки заканчивает её и сохраняет текст',
      (tester) async {
        final h = _Harness(grading: FakeGradingRepository([fakeGrade()]));
        await h.pump(tester);
        await tester.tap(_key('open-mic'));
        await tester.pump();
        await tester.pump();
        h.speech.say('скрипт отражается без экранирования');
        await tester.pump();
        await tester.ensureVisible(_key('open-check'));
        await tester.tap(_key('open-check'));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(h.speech.cancels, greaterThan(0));
        expect(
          h.grading.requests.single.answerText,
          'скрипт отражается без экранирования',
        );
        expect(h.grading.requests.single.inputMode, AnswerInputMode.voice);
      },
    );

    testWidgets('уход в фон заканчивает диктовку, текст остаётся', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      h.speech.say('сказал');
      await tester.pump();
      // `inactive` (системный диалог разрешения) диктовку не прерывает.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(_key('open-mic-listening'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      _foreground(tester);
      expect(h.speech.cancels, greaterThan(0));
      expect(_key('open-mic-listening'), findsNothing);
      expect(find.text('сказал'), findsOneWidget);
    });

    testWidgets('отказ в разрешении (Android): пояснение и кнопка настроек', (
      tester,
    ) async {
      final h = _Harness(
        speech: FakeSpeechService()
          ..failOnListen = SpeechFailure.permissionDenied,
      );
      await h.pump(tester);
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Нет доступа к микрофону'), findsOneWidget);
      expect(_key('open-mic-settings'), findsOneWidget);
      await tester.tap(_key('open-mic-settings'));
      expect(h.opener.opened, 1);
      // Текстовый ввод работает.
      await _type(tester, _answer);
      expect(find.text(_answer), findsOneWidget);
    });

    testWidgets('отказ в разрешении (web): пояснение про браузер, без кнопки', (
      tester,
    ) async {
      final h = _Harness(
        speech: FakeSpeechService()
          ..failOnListen = SpeechFailure.permissionDenied,
        opener: FakeAppSettingsOpener(isSupported: false),
      );
      await h.pump(tester);
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Браузер не дал доступ'), findsOneWidget);
      expect(_key('open-mic-settings'), findsNothing);
    });

    testWidgets('нет поддержки: микрофон выключен, пояснение, текст работает', (
      tester,
    ) async {
      final h = _Harness(
        speech: FakeSpeechService(supportValue: SpeechSupport.unsupported),
      );
      await h.pump(tester);
      expect(tester.widget<IconButton>(_key('open-mic')).onPressed, isNull);
      expect(find.textContaining('Диктовка в этом браузере'), findsOneWidget);
      await tester.tap(_key('open-mic'), warnIfMissed: false);
      expect(h.speech.listens, 0);
      await _type(tester, _answer);
      expect(find.text(_answer), findsOneWidget);
    });

    testWidgets(
      'сервис оказался недоступен при запуске: микрофон выключается',
      (tester) async {
        final h = _Harness(
          speech: FakeSpeechService()..failOnListen = SpeechFailure.unsupported,
        );
        await h.pump(tester);
        await tester.tap(_key('open-mic'));
        await tester.pump();
        await tester.pump();
        expect(tester.widget<IconButton>(_key('open-mic')).onPressed, isNull);
        expect(find.textContaining('Диктовка в этом браузере'), findsOneWidget);
      },
    );

    final failures = {
      SpeechFailure.noSpeech: 'Речь не расслышали',
      SpeechFailure.network: 'нужна сеть',
      SpeechFailure.languageUnavailable: 'нет распознавания речи',
      SpeechFailure.other: 'Диктовка не сработала',
    };
    for (final MapEntry(key: failure, value: text) in failures.entries) {
      testWidgets('сбой $failure: сообщение, повтор возможен', (tester) async {
        final h = _Harness(speech: FakeSpeechService()..failOnListen = failure);
        await h.pump(tester);
        await tester.tap(_key('open-mic'));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining(text), findsOneWidget);
        expect(_key('open-mic-listening'), findsNothing);
        expect(
          tester.widget<IconButton>(_key('open-mic')).onPressed,
          isNotNull,
        );
        // Следующая попытка снимает сообщение.
        h.speech.failOnListen = null;
        await tester.tap(_key('open-mic'));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining(text), findsNothing);
        expect(_key('open-mic-listening'), findsOneWidget);
      });
    }

    testWidgets('таймаут тишины: сессия закрылась без слов — «не расслышали»', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      await h.speech.finish();
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Речь не расслышали'), findsOneWidget);
      expect(_key('open-mic-listening'), findsNothing);
    });

    testWidgets('язык распознавания — язык колоды', (tester) async {
      final h = _Harness(lang: 'en');
      await h.pump(tester);
      await tester.tap(_key('open-mic'));
      await tester.pump();
      await tester.pump();
      expect(h.speech.lastLang, 'en');
    });
  });

  testWidgets('доступность: тап-цели не меньше 48 dp', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    for (final k in ['open-check', 'open-skip', 'open-mic']) {
      final size = tester.getSize(_key(k));
      expect(size.width, greaterThanOrEqualTo(48), reason: k);
      expect(size.height, greaterThanOrEqualTo(48), reason: k);
    }
  });
}
