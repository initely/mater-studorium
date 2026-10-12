import 'package:mater_studorium/features/catalog/domain/local_item.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/domain/item_content.dart';
import 'package:mater_studorium/features/session/domain/review_log.dart';
import 'package:mater_studorium/features/session/domain/session_repository.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

final fakeNow = DateTime.utc(2026, 10, 11, 12);

Question fakeQuestion(String id, QuestionType type) => Question(
  id: id,
  type: type,
  prompt: 'p',
  payload: switch (type) {
    QuestionType.flip => const QuestionPayload.flip(back: 'b'),
    QuestionType.mcq => const QuestionPayload.mcq(
      options: [
        McqOption(id: 'a', text: 'a'),
        McqOption(id: 'b', text: 'b'),
      ],
      correct: ['a'],
      multiple: false,
    ),
    QuestionType.open => const QuestionPayload.open(
      referenceAnswer: 'r',
      rubric: [
        RubricPoint(id: 'p1', text: 't', weight: 1, required: true),
        RubricPoint(id: 'p2', text: 't', weight: 1, required: false),
      ],
    ),
    QuestionType.cloze => const QuestionPayload.cloze(
      blanks: [
        ClozeBlank(id: 'b1', accepted: ['x']),
      ],
    ),
    _ => throw ArgumentError('нет заготовки для $type'),
  },
);

/// Знание `id` колоды [deckId]; вопросы по умолчанию `id.mcq` и `id.open`.
ItemContent fakeContent(
  String id, {
  String deckId = 'd1',
  int deckVersion = 1,
  List<Question>? questions,
}) => ItemContent(
  item: LocalItem(
    id: id,
    deckId: deckId,
    title: id,
    fact: 'fact',
    explanationShort: 's',
    explanationLong: 'l',
    refs: const [],
    retired: false,
  ),
  deckVersion: deckVersion,
  questions:
      questions ??
      [
        fakeQuestion('$id.mcq', QuestionType.mcq),
        fakeQuestion('$id.open', QuestionType.open),
      ],
);

/// Состояние знания `review` с заданным `due`.
ItemState fakeState(
  String itemId,
  DateTime due, {
  String deckId = 'd1',
  double stability = 5,
  String? lastQuestionId,
}) => ItemState(
  itemId: itemId,
  deckId: deckId,
  due: due,
  stability: stability,
  difficulty: 5,
  elapsedDays: 1,
  scheduledDays: 5,
  reps: 3,
  lapses: 0,
  state: SrsState.review,
  lastReview: due.subtract(const Duration(days: 5)),
  lastQuestionId: lastQuestionId,
  updatedAt: due,
);

/// Лог ответа для проверок «новые сегодня» и `lastShownAt`.
ReviewLog fakeLog(
  String itemId,
  DateTime at, {
  String? questionId,
  String id = '',
}) => ReviewLog(
  id: id.isEmpty ? 'log-$itemId-${at.microsecondsSinceEpoch}' : id,
  deckId: 'd1',
  deckVersion: 1,
  itemId: itemId,
  questionId: questionId ?? '$itemId.mcq',
  questionType: QuestionType.mcq,
  rating: Rating.good,
  gradeSource: GradeSource.auto,
  durationMs: 1000,
  reviewedAt: at,
);

/// Репозиторий в памяти с теми же правилами выборки, что у drift-версии:
/// порядок, фильтр по колодам, «новое» = нет состояния.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({
    this.contents = const [],
    Map<String, ItemState>? states,
    List<ReviewLog>? logs,
  }) : states = states ?? {},
       logs = logs ?? [];

  /// Знания в порядке колоды.
  final List<ItemContent> contents;
  final Map<String, ItemState> states;
  final List<ReviewLog> logs;

  /// Знания, которых `contentFor` не отдаёт (вопросы скрыли, пока строилась
  /// очередь), хотя `dueStates`/`newItems` их вернули.
  final Set<String> missingContent = {};

  /// Что построитель спрашивал последним.
  DateTime? countFrom;
  DateTime? countTo;
  Set<String>? lastDeckIds;
  int? lastNewLimit;

  bool _inDecks(ItemContent c, Set<String>? deckIds) =>
      deckIds == null || deckIds.contains(c.item.deckId);

  ItemContent? _content(String itemId) =>
      contents.where((c) => c.item.id == itemId).firstOrNull;

  @override
  Future<List<ItemState>> dueStates({
    required DateTime now,
    Set<String>? deckIds,
  }) async {
    lastDeckIds = deckIds;
    return [
      for (final s in states.values)
        if (!s.due.isAfter(now) &&
            _content(s.itemId) != null &&
            _inDecks(_content(s.itemId)!, deckIds))
          s,
    ]..sort((a, b) {
      final byDue = a.due.compareTo(b.due);
      return byDue != 0 ? byDue : a.itemId.compareTo(b.itemId);
    });
  }

  @override
  Future<List<LocalItem>> newItems({
    Set<String>? deckIds,
    required int limit,
  }) async {
    lastNewLimit = limit;
    return [
      for (final c in contents)
        if (!states.containsKey(c.item.id) && _inDecks(c, deckIds)) c.item,
    ].take(limit).toList();
  }

  @override
  Future<int> countNewItemsFirstShown({
    required DateTime from,
    required DateTime to,
  }) async {
    countFrom = from;
    countTo = to;
    final byItem = <String, DateTime>{};
    for (final l in logs) {
      final first = byItem[l.itemId];
      if (first == null || l.reviewedAt.isBefore(first)) {
        byItem[l.itemId] = l.reviewedAt;
      }
    }
    return byItem.values
        .where((first) => !first.isBefore(from) && first.isBefore(to))
        .length;
  }

  @override
  Future<DateTime?> nextDue({
    required DateTime after,
    Set<String>? deckIds,
  }) async {
    final future = [
      for (final s in states.values)
        if (s.due.isAfter(after)) s.due,
    ]..sort();
    return future.firstOrNull;
  }

  @override
  Future<Map<String, ItemContent>> contentFor(Set<String> itemIds) async => {
    for (final c in contents)
      if (itemIds.contains(c.item.id) &&
          c.questions.isNotEmpty &&
          !missingContent.contains(c.item.id))
        c.item.id: c,
  };

  @override
  Future<Map<String, DateTime>> lastShownAt(Set<String> itemIds) async {
    final result = <String, DateTime>{};
    for (final l in logs) {
      if (!itemIds.contains(l.itemId)) continue;
      final last = result[l.questionId];
      if (last == null || l.reviewedAt.isAfter(last)) {
        result[l.questionId] = l.reviewedAt;
      }
    }
    return result;
  }

  @override
  Future<void> recordReview({
    required ReviewLog log,
    required ItemState state,
  }) async {
    logs.add(log);
    states[state.itemId] = state;
  }
}
