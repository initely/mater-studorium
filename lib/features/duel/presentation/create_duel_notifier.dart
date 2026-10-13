import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/uuid.dart';
import '../data/duel_providers.dart';
import '../domain/duel_question_picker.dart';
import 'duel_action_state.dart';

/// Создание дуэли (T22): берёт 5 случайных автопроверяемых вопросов из
/// скачанной колоды и просит сервер создать дуэль. Ошибки превращаются в
/// состояние, наружу не бросаются.
class CreateDuelNotifier extends Notifier<DuelActionState> {
  // uuid дуэли живёт до успеха: повтор после обрыва сети (запрос мог дойти до
  // сервера) возвращает ту же дуэль, а не заводит вторую. Для другой колоды
  // заводится новый.
  String? _pendingId;
  String? _pendingDeckId;

  @override
  DuelActionState build() => const DuelActionState();

  Future<void> create(String deckId) async {
    if (state.busy) return;
    state = const DuelActionState(busy: true);
    try {
      final snapshot = await ref
          .read(duelQuestionSourceProvider)
          .snapshot(deckId);
      if (snapshot == null) throw DeckNotFoundError(deckId);
      final questionIds = pickDuelQuestions(
        snapshot.candidates,
        ref.read(randomProvider),
      );
      if (_pendingDeckId != deckId) _pendingId = null;
      _pendingDeckId = deckId;
      final duelId = _pendingId ??= ref.read(uuidGeneratorProvider)();
      final duel = await ref
          .read(duelRepositoryProvider)
          .create(
            duelId: duelId,
            deckId: deckId,
            deckVersion: snapshot.deckVersion,
            questionIds: questionIds,
          );
      _pendingId = null;
      if (!ref.mounted) return;
      state = DuelActionState(duel: duel);
    } catch (e) {
      if (!ref.mounted) return;
      state = DuelActionState(error: _asAppError(e));
    }
  }

  AppError _asAppError(Object e) => e is AppError
      ? e
      : UnexpectedError('Создание дуэли: неожиданная ошибка', cause: e);
}

final createDuelProvider =
    NotifierProvider.autoDispose<CreateDuelNotifier, DuelActionState>(
      CreateDuelNotifier.new,
    );
