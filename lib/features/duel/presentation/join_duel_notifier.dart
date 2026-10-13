import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/duel_providers.dart';
import '../domain/duel_code.dart';
import 'duel_action_state.dart';

/// Вход в дуэль по коду (T22, AC10.2). Код неверного вида не уходит на сервер
/// (там он всё равно «не найден»). После входа колода докачивается, если её нет
/// на устройстве; неудача докачки вход не отменяет: экран дуэли предложит
/// скачать колоду ещё раз.
class JoinDuelNotifier extends Notifier<DuelActionState> {
  @override
  DuelActionState build() => const DuelActionState();

  Future<void> join(String input) async {
    if (state.busy) return;
    final code = normalizeDuelCode(input);
    if (code == null) {
      state = const DuelActionState(error: DuelCodeNotFoundError());
      return;
    }
    state = const DuelActionState(busy: true);
    try {
      final duel = await ref.read(duelRepositoryProvider).join(code);
      try {
        await ref.read(catalogRepositoryProvider).download(duel.deckId);
      } on AppError {
        // Колоду можно скачать позже с экрана дуэли.
      }
      if (!ref.mounted) return;
      state = DuelActionState(duel: duel);
    } catch (e) {
      if (!ref.mounted) return;
      state = DuelActionState(error: _asAppError(e));
    }
  }

  AppError _asAppError(Object e) => e is AppError
      ? e
      : UnexpectedError('Вход в дуэль: неожиданная ошибка', cause: e);
}

final joinDuelProvider =
    NotifierProvider.autoDispose<JoinDuelNotifier, DuelActionState>(
      JoinDuelNotifier.new,
    );
