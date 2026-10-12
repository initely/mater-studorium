// Модель жалобы, очистка текстов и проверка перед отправкой (T20, ADR-33).
// Правила совпадают с ограничениями таблицы reports (0005_reports.sql).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:mater_studorium/features/reports/domain/report.dart';
import 'package:mater_studorium/features/reports/domain/report_outbox.dart';
import 'package:mater_studorium/features/reports/domain/report_reason.dart';
import 'package:mater_studorium/features/reports/domain/report_text.dart';
import 'package:mater_studorium/features/reports/domain/report_validator.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

const _id = 'aaaaaaaa-0000-4000-8000-000000000001';

Report _question({
  String id = _id,
  String deckId = 'infosec',
  int deckVersion = 1,
  String questionId = 'xss.q1',
  ReportReason reason = ReportReason.typo,
  String? comment,
  String? questionText = 'Что такое XSS?',
}) => Report.question(
  id: id,
  deckId: deckId,
  deckVersion: deckVersion,
  questionId: questionId,
  reason: reason,
  comment: comment,
  questionText: questionText,
);

Report _disagree({
  String answerText = 'вставка скрипта в страницу',
  GradeVerdict verdict = GradeVerdict.partial,
  double? score = 0.55,
  Rating rating = Rating.good,
  String? comment,
}) => Report.disagreement(
  id: _id,
  deckId: 'infosec',
  deckVersion: 2,
  questionId: 'xss.q2',
  answerText: answerText,
  verdict: verdict,
  userRating: rating,
  llmScore: score,
  comment: comment,
  questionText: 'Объясните XSS',
);

void main() {
  group('sanitizeReportText', () {
    test('пусто и пробелы — null; края обрезаются', () {
      expect(sanitizeReportText(null, max: 10), isNull);
      expect(sanitizeReportText('', max: 10), isNull);
      expect(sanitizeReportText(' \n\t ', max: 10), isNull);
      expect(sanitizeReportText('  привет \n', max: 10), 'привет');
    });

    test('NUL и управляющие символы вырезаются, \\n и \\t остаются', () {
      expect(sanitizeReportText('при\u0000ве\u0001т\u007f', max: 50), 'привет');
      expect(sanitizeReportText('a\nb\tc', max: 50), 'a\nb\tc');
      expect(sanitizeReportText('\u0000\u0001', max: 50), isNull);
    });

    test('непарный суррогат заменяется на U+FFFD, пара остаётся', () {
      expect(sanitizeReportText('a\ud800b', max: 50), 'a�b');
      expect(sanitizeReportText('x\udc00', max: 50), 'x�');
      expect(sanitizeReportText('😀 ok', max: 50), '😀 ok');
      // Результат кодируется в UTF-8 без потерь (иначе PGRST102).
      final cleaned = sanitizeReportText('a\ud800b\u0000c', max: 50)!;
      expect(utf8.decode(utf8.encode(cleaned)), cleaned);
    });

    test('невидимые символы (Cf) вырезаются; из одних них — null', () {
      expect(
        sanitizeReportText('\u200b\u00a0\u3000\u202e\ufeff\u2060', max: 50),
        isNull,
      );
      expect(sanitizeReportText('при\u202eве\u200bт\ufeff', max: 50), 'привет');
      expect(sanitizeReportText('\u00a0 текст \u3000', max: 50), 'текст');
    });

    test('обрезка по длине не рвёт суррогатную пару', () {
      expect(sanitizeReportText('ab😀cd', max: 3), 'ab');
      expect(sanitizeReportText('ab😀cd', max: 4), 'ab😀');
      expect(sanitizeReportText('я' * 600, max: 500)!.length, 500);
      // Пробел на границе обрезки не остаётся хвостом.
      expect(sanitizeReportText('abc def', max: 4), 'abc');
    });
  });

  group('Report', () {
    test('жалоба: тексты очищаются и обрезаются при создании', () {
      final r = _question(
        comment: ' ${'я' * 600} \u0000',
        questionText: 'Что\u0001 такое?',
      );
      expect(r.comment!.length, kMaxReportCommentChars);
      expect(r.questionText, 'Что такое?');
      expect(r.disagreement, isNull);
    });

    test('toJson: тело RPC submit_report; fromJson возвращает то же', () {
      final r = _question(
        comment: 'опечатка в слове',
        reason: ReportReason.typo,
      );
      expect(r.toJson(), {
        'id': _id,
        'deck_id': 'infosec',
        'deck_version': 1,
        'question_id': 'xss.q1',
        'reason': 'typo',
        'comment': 'опечатка в слове',
        'question_text': 'Что такое XSS?',
      });
      final back = Report.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back.toJson(), r.toJson());
    });

    test('«не согласен»: поля спора в JSON и обратно', () {
      final r = _disagree(comment: 'ИИ придирается');
      final json = r.toJson();
      expect(json['reason'], 'grading_disagree');
      expect(json['answer_text'], 'вставка скрипта в страницу');
      expect(json['llm_verdict'], 'partial');
      expect(json['llm_score'], 0.55);
      expect(json['user_rating'], 3);
      final back = Report.fromJson(jsonDecode(jsonEncode(json)));
      expect(back.toJson(), json);
      expect(back.disagreement!.userRating, Rating.good);
      expect(back.disagreement!.verdict, GradeVerdict.partial);
    });

    test('балл округляется до 4 знаков: 1e-50 не уходит на сервер', () {
      expect(_disagree(score: 1e-50).disagreement!.llmScore, 0.0);
      expect(_disagree(score: 0.55555).disagreement!.llmScore, 0.5556);
      expect(_disagree(score: 1.0).disagreement!.llmScore, 1.0);
      expect(
        jsonEncode(_disagree(score: 1e-50).toJson()),
        isNot(contains('e-')),
      );
      expect(_disagree(score: null).disagreement!.llmScore, isNull);
      // NaN не округляется (round бросил бы), но отчёт невалиден.
      final nan = _disagree(score: double.nan);
      expect(nan.disagreement!.llmScore!.isNaN, isTrue);
      expect(isValidReport(nan), isFalse);
    });

    test('у обычной жалобы нет полей спора', () {
      final json = _question().toJson();
      expect(json.keys, isNot(contains('answer_text')));
      expect(json.keys, isNot(contains('llm_verdict')));
      expect(json.keys, isNot(contains('user_rating')));
    });

    test('fromJson: неверная форма — FormatException', () {
      final ok = _question().toJson();
      for (final bad in <Object?>[
        null,
        'строка',
        [1],
        {...ok, 'reason': 'spam'},
        {...ok}..remove('id'),
        {...ok, 'deck_version': 'x'},
        {...ok, 'reason': 'grading_disagree'}, // без полей спора
        _disagree().toJson()..['llm_verdict'] = 'unsure',
        _disagree().toJson()..['llm_verdict'] = 'нет',
        _disagree().toJson()..['user_rating'] = 9,
      ]) {
        expect(
          () => Report.fromJson(bad),
          throwsA(isA<FormatException>()),
          reason: '$bad',
        );
      }
    });

    test('fromJson очищает тексты ещё раз (старый или чужой клиент)', () {
      final json = _question().toJson()
        ..['comment'] = 'при\u0001вет'
        ..['question_text'] = 'я' * 700;
      final r = Report.fromJson(json);
      expect(r.comment, 'привет');
      expect(r.questionText!.length, kMaxReportQuestionTextChars);
    });

    test('запись очереди: payload — тело RPC, kind report', () {
      final now = DateTime.utc(2026, 10, 12, 10);
      final entry = reportOutboxEntry(_question(), now);
      expect(entry.kind.name, 'report');
      expect(entry.createdAt, now);
      expect(jsonDecode(entry.payloadJson), _question().toJson());
    });
  });

  group('isValidReport (правила сервера)', () {
    test('нормальные жалобы валидны', () {
      expect(isValidReport(_question()), isTrue);
      expect(isValidReport(_question(comment: 'я' * 500)), isTrue);
      expect(isValidReport(_question(questionText: null)), isTrue);
      expect(isValidReport(_disagree()), isTrue);
      expect(isValidReport(_disagree(score: null)), isTrue);
      expect(isValidReport(_disagree(answerText: 'я' * 2000)), isTrue);
    });

    test('id не uuid, колода и вопрос вне формата, версия вне границ', () {
      expect(isValidReport(_question(id: 'не-uuid')), isFalse);
      expect(isValidReport(_question(deckId: 'Bad Deck')), isFalse);
      expect(isValidReport(_question(deckId: 'a' * 65)), isFalse);
      expect(isValidReport(_question(questionId: 'Bad Id')), isFalse);
      expect(isValidReport(_question(questionId: 'a' * 129)), isFalse);
      expect(isValidReport(_question(deckVersion: 0)), isFalse);
      expect(isValidReport(_question(deckVersion: 1000001)), isFalse);
    });

    test('«не согласен»: пустой ответ и балл вне 0…1 не принимаются', () {
      expect(isValidReport(_disagree(answerText: '  \u0000 ')), isFalse);
      expect(isValidReport(_disagree(score: 1.5)), isFalse);
      expect(isValidReport(_disagree(score: -0.1)), isFalse);
      expect(isValidReport(_disagree(score: double.nan)), isFalse);
      expect(isValidReport(_disagree(score: double.infinity)), isFalse);
    });
  });

  test(
    'причины: wire совпадает с CHECK сервера; выбираются все, кроме спора',
    () {
      expect(
        [for (final r in ReportReason.values) r.wire],
        [
          'wrong_answer',
          'unclear',
          'typo',
          'bad_source',
          'other',
          'grading_disagree',
        ],
      );
      expect(
        ReportReason.choosable,
        isNot(contains(ReportReason.gradingDisagree)),
      );
      expect(ReportReason.choosable, hasLength(5));
      expect(ReportReason.fromWire('typo'), ReportReason.typo);
      expect(ReportReason.fromWire('нет'), isNull);
    },
  );
}
