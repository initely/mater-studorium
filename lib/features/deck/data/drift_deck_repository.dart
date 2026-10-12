import 'dart:async';

import '../../../core/db/decks_dao.dart';
import '../../../core/db/review_dao.dart';
import '../../../core/errors/app_error.dart';
import '../../catalog/domain/local_deck.dart';
import '../domain/deck_details.dart';
import '../domain/deck_progress.dart';
import '../domain/deck_repository.dart';

/// [DeckRepository] поверх [DecksDao] и [ReviewDao].
class DriftDeckRepository implements DeckRepository {
  DriftDeckRepository({
    required this._decks,
    required this._review,
    required this._userId,
  });

  final DecksDao _decks;
  final ReviewDao _review;

  /// Текущий пользователь; берётся при подписке и может бросить `AuthError`.
  final String Function() _userId;

  @override
  Stream<DeckDetails?> watch(String deckId) {
    late StreamController<DeckDetails?> controller;
    StreamSubscription<LocalDeck?>? deckSub;
    StreamSubscription<DeckProgress>? progressSub;
    // Колода и прогресс приходят из двух запросов; наружу отдаём пару, когда
    // есть обе половины.
    var hasDeck = false;
    LocalDeck? deck;
    DeckProgress? progress;

    void emit() {
      if (!hasDeck || progress == null || controller.isClosed) return;
      final d = deck;
      controller.add(
        d == null ? null : DeckDetails(deck: d, progress: progress!),
      );
    }

    controller = StreamController<DeckDetails?>(
      onListen: () {
        final String userId;
        try {
          userId = _userId();
        } on AppError catch (e) {
          controller.addError(e);
          return;
        }
        deckSub = _decks.watchDeck(deckId).listen((d) {
          hasDeck = true;
          deck = d;
          emit();
        }, onError: controller.addError);
        progressSub = _review.watchDeckProgress(userId, deckId).listen((p) {
          progress = p;
          emit();
        }, onError: controller.addError);
      },
      // Обе отмены стартуют сразу: drift завершает отмену отложенным таймером.
      onCancel: () => Future.wait([?deckSub?.cancel(), ?progressSub?.cancel()]),
    );
    return controller.stream;
  }

  @override
  Future<void> delete(String deckId) async {
    try {
      await _decks.deleteDeck(deckId);
    } on Exception catch (e) {
      throw LocalStorageError('не удалось удалить колоду $deckId', cause: e);
    }
  }
}
