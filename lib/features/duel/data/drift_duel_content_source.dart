import '../../../core/db/decks_dao.dart';
import '../../../core/errors/app_error.dart';
import '../domain/duel_content.dart';
import '../domain/duel_question_picker.dart';

/// [DuelContentSource] поверх локальной БД: вопросы скачанной колоды. Ошибки
/// drift превращаются в [LocalStorageError].
class DriftDuelContentSource implements DuelContentSource {
  DriftDuelContentSource(this._decks);

  final DecksDao _decks;

  @override
  Future<DuelContent?> load(String deckId, List<String> questionIds) async {
    try {
      final deck = await _decks.getDeck(deckId);
      if (deck == null) return null;
      final rows = await _decks.duelQuestions(deckId, questionIds, {
        for (final t in kDuelQuestionTypes) t.wire,
      });
      return DuelContent(
        deckVersion: deck.version,
        questions: {
          for (final r in rows)
            r.question.id: DuelQuestionContent(
              question: r.question,
              item: r.item,
            ),
        },
      );
    } on AppError {
      rethrow;
    } on Exception catch (e) {
      throw LocalStorageError('не удалось прочитать вопросы дуэли', cause: e);
    }
  }
}
