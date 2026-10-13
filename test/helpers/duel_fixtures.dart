import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/local_item.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/duel/domain/duel.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer_queue.dart';
import 'package:mater_studorium/features/duel/domain/duel_content.dart';
import 'package:mater_studorium/features/duel/domain/duel_seen_store.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';

import 'db_fixtures.dart';
import 'fake_duel_repository.dart';

/// Настоящий uuid: клиент отправляет только записи с корректным id дуэли.
const kDuelId = '00000000-0000-4000-8000-0000000000d1';

/// Колода дуэли в тестах и её вопросы `<deck>.1.q1` … (`mcq` с одним верным
/// вариантом `a`, варианты `a`, `b`, `c`).
const kDuelDeckId = 'duel-deck';

List<String> duelQuestionIds([int n = 5]) => [
  for (var k = 1; k <= n; k++) '$kDuelDeckId.$k.q1',
];

/// Вопрос `mcq`: верный вариант `a`.
Question mcqQuestion(String id, {String? prompt, String? explanation}) =>
    Question(
      id: id,
      type: QuestionType.mcq,
      prompt: prompt ?? 'Текст $id',
      explanationShort: explanation,
      payload: const QuestionPayload.mcq(
        options: [
          McqOption(id: 'a', text: 'Первый'),
          McqOption(id: 'b', text: 'Второй'),
          McqOption(id: 'c', text: 'Третий'),
        ],
        correct: ['a'],
        multiple: false,
      ),
    );

/// Колода из [n] знаний с одним `mcq` у каждого; знание `<deck>.k` с разбором
/// «Разбор k».
Deck duelDeck({int n = 5, int version = 2}) {
  final template = goodDeck().items[0];
  return goodDeck().copyWith(
    id: kDuelDeckId,
    version: version,
    items: [
      for (var k = 1; k <= n; k++)
        template.copyWith(
          id: '$kDuelDeckId.$k',
          explanationShort: 'Разбор $k',
          questions: [
            mcqQuestion('$kDuelDeckId.$k.q1', prompt: 'Вопрос номер $k'),
          ],
        ),
    ],
  );
}

/// Дуэль для игры: колода [kDuelDeckId], вопросы [duelQuestionIds].
Duel playDuel({
  String id = kDuelId,
  DuelStatus status = DuelStatus.active,
  bool isCreator = false,
  bool otherJoined = true,
  String? otherName = 'Алиса',
  DateTime? myDoneAt,
  DateTime? otherDoneAt,
  int deckVersion = 2,
  List<String>? questionIds,
}) => duelFixture(
  id: id,
  code: isCreator ? 'K7Q2MX' : null,
  deckId: kDuelDeckId,
  deckVersion: deckVersion,
  status: status,
  isCreator: isCreator,
  otherJoined: otherJoined,
  otherName: otherName,
  myDoneAt: myDoneAt,
  otherDoneAt: otherDoneAt,
).copyWith(questionIds: questionIds ?? duelQuestionIds());

/// Содержимое дуэли для тестов без БД: вопросы по id.
DuelContent contentOf({
  int n = 5,
  int version = 2,
  Set<String> missing = const {},
}) {
  final deck = duelDeck(n: n, version: version);
  return DuelContent(
    deckVersion: version,
    questions: {
      for (final item in deck.items)
        for (final q in item.questions)
          if (!missing.contains(q.id))
            q.id: DuelQuestionContent(
              question: q,
              item: LocalItem(
                id: item.id,
                deckId: kDuelDeckId,
                title: item.title,
                fact: item.fact,
                explanationShort: item.explanationShort,
                explanationLong: '',
                refs: const [],
                retired: false,
              ),
            ),
    },
  );
}

/// Источник вопросов дуэли в памяти.
class FakeDuelContentSource implements DuelContentSource {
  FakeDuelContentSource({this.content});

  /// `null` — колоды нет на устройстве.
  DuelContent? content;
  Object? error;
  var loads = 0;

  @override
  Future<DuelContent?> load(String deckId, List<String> questionIds) async {
    loads++;
    if (error != null) throw error!;
    return content;
  }
}

/// Очередь ответов дуэли в памяти (та же семантика, что у drift-очереди:
/// повтор вопроса дуэли не принимается).
class FakeDuelAnswerQueue implements DuelAnswerQueue {
  FakeDuelAnswerQueue({this.dedupe = true});

  /// `false` — очередь не защищает от повтора: проверка, что защищается
  /// сам контроллер.
  final bool dedupe;
  final queued = <DuelAnswerPayload>[];
  Object? enqueueError;
  var enqueueCalls = 0;

  @override
  Future<bool> enqueue(DuelAnswerPayload answer) async {
    enqueueCalls++;
    if (enqueueError != null) throw enqueueError!;
    if (dedupe &&
        queued.any(
          (a) => a.duelId == answer.duelId && a.questionId == answer.questionId,
        )) {
      return false;
    }
    queued.add(answer);
    return true;
  }

  @override
  Future<Set<String>> pendingQuestionIds(String duelId) async => {
    for (final a in queued)
      if (a.duelId == duelId) a.questionId,
  };
}

/// Открытые результаты в памяти.
class FakeDuelSeenStore implements DuelSeenStore {
  final seen = <String>{};
  Object? error;

  @override
  Future<Set<String>> seenResults() async {
    if (error != null) throw error!;
    return {...seen};
  }

  @override
  Future<void> markResultSeen(String duelId) async {
    if (error != null) throw error!;
    seen.add(duelId);
  }
}

/// Ответ сервера (строка `duel_answers`) для результата.
DuelAnswerRecord record(
  String questionId, {
  List<String> selected = const ['a'],
  bool correct = true,
  int ms = 1000,
}) => DuelAnswerRecord(
  questionId: questionId,
  answer: {'selected': selected},
  isCorrect: correct,
  durationMs: ms,
);

/// Ошибка сети для сценариев «офлайн».
const offline = NetworkError('нет сети');
