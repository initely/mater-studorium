import '../../../core/db/decks_dao.dart';
import '../../../core/errors/app_error.dart';
import '../domain/duel_question_picker.dart';
import '../domain/duel_question_source.dart';

/// [DuelQuestionSource] поверх локальной БД: вопросы скачанной колоды.
/// Ошибки drift превращаются в [LocalStorageError].
class DriftDuelQuestionSource implements DuelQuestionSource {
  DriftDuelQuestionSource(this._decks);

  final DecksDao _decks;

  @override
  Future<DuelDeckSnapshot?> snapshot(String deckId) async {
    try {
      final deck = await _decks.getDeck(deckId);
      if (deck == null) return null;
      final rows = await _decks.questionsOfTypes(deckId, {
        for (final t in kDuelQuestionTypes) t.wire,
      });
      return DuelDeckSnapshot(
        deckVersion: deck.version,
        candidates: [
          for (final r in rows)
            DuelCandidate(questionId: r.questionId, itemId: r.itemId),
        ],
      );
    } on AppError {
      rethrow;
    } on Exception catch (e) {
      throw LocalStorageError('не удалось прочитать вопросы колоды', cause: e);
    }
  }
}
