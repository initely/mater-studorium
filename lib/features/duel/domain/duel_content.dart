import '../../catalog/domain/local_item.dart';
import '../../catalog/domain/question.dart';
import '../../catalog/domain/question_type.dart';
import 'duel_question_picker.dart';

/// Вопрос дуэли из локальной колоды вместе со знанием (для разбора).
class DuelQuestionContent {
  const DuelQuestionContent({required this.question, required this.item});

  final Question question;
  final LocalItem item;

  /// Годится для дуэли: автопроверяемый формат из [kDuelQuestionTypes].
  bool get isPlayable => kDuelQuestionTypes.contains(question.type);
}

/// Что в локальной колоде есть из вопросов дуэли.
class DuelContent {
  const DuelContent({required this.deckVersion, required this.questions});

  /// Версия колоды на устройстве. Соперник играет по ТЕКУЩЕЙ скачанной версии,
  /// а не по `deck_version` дуэли (ADR-35, п. 11), поэтому вопрос мог
  /// измениться или исчезнуть.
  final int deckVersion;

  /// Годные вопросы: есть в колоде, автопроверяемые, не скрыты, знание не
  /// исчезло из версии. Нет ключа — вопрос недоступен.
  final Map<String, DuelQuestionContent> questions;
}

/// Откуда клиент берёт вопросы дуэли для игры и разбора: из скачанной колоды
/// (контента колод в БД сервера нет, ADR-7). Реализация в `data/`.
abstract interface class DuelContentSource {
  /// Вопросы [questionIds] из колоды [deckId]; `null`, если колоды нет на
  /// устройстве.
  Future<DuelContent?> load(String deckId, List<String> questionIds);
}

/// Вопрос набора дуэли: годный к показу или недоступный на этом устройстве.
class DuelSlot {
  const DuelSlot({required this.questionId, this.content});

  final String questionId;

  /// `null` — вопроса нет в локальной колоде, он не автопроверяемый или
  /// скрыт жалобой (ADR-36).
  final DuelQuestionContent? content;

  bool get isPlayable => content != null;
}

/// Раскладывает набор дуэли [questionIds] по слотам в порядке набора. Вопрос
/// годен, если он есть в [content], автопроверяемый и его формат умеет
/// показывать приложение ([supportedTypes], реестр форматов).
List<DuelSlot> resolveDuelSlots(
  List<String> questionIds,
  DuelContent content, {
  required Set<QuestionType> supportedTypes,
}) => [
  for (final id in questionIds)
    DuelSlot(
      questionId: id,
      content: switch (content.questions[id]) {
        final q?
            when q.isPlayable && supportedTypes.contains(q.question.type) =>
          q,
        _ => null,
      },
    ),
];
