import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/deck_providers.dart';

/// Итог проверки обновления колоды.
sealed class DeckUpdateResult {
  const DeckUpdateResult();
}

/// Колода стала версии [version].
final class DeckUpdated extends DeckUpdateResult {
  const DeckUpdated(this.version);

  final int version;
}

/// Установлена последняя версия.
final class DeckUpToDate extends DeckUpdateResult {
  const DeckUpToDate();
}

/// Состояние действий на экране колоды: обновление и удаление.
class DeckActionsState {
  const DeckActionsState({this.busy = false, this.result, this.error});

  /// Идёт обновление или удаление: кнопки заблокированы.
  final bool busy;

  /// Итог последнего обновления (успех).
  final DeckUpdateResult? result;

  /// Последняя неудача (обновления или удаления).
  final AppError? error;
}

/// Действия экрана колоды: «Обновить» и «Удалить». Ошибки репозиториев
/// превращаются в состояние (`AppError`), наружу не бросаются.
class DeckActionsNotifier extends Notifier<DeckActionsState> {
  DeckActionsNotifier(this.deckId);

  final String deckId;

  @override
  DeckActionsState build() => const DeckActionsState();

  /// Скачивает новую версию, если она есть на сервере; без сети — ошибка
  /// `NetworkError`, прежняя версия остаётся (ТЗ AC2.3).
  Future<void> checkUpdate() async {
    if (state.busy) return;
    state = const DeckActionsState(busy: true);
    try {
      final before = ref.read(deckDetailsProvider(deckId)).value?.deck.version;
      final local = await ref.read(catalogRepositoryProvider).download(deckId);
      if (!ref.mounted) return;
      state = DeckActionsState(
        result: local.version == before
            ? const DeckUpToDate()
            : DeckUpdated(local.version),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = DeckActionsState(error: _asAppError(e));
    }
  }

  /// Удаляет колоду с устройства (прогресс остаётся, ADR-26). `true` — удалена.
  Future<bool> delete() async {
    if (state.busy) return false;
    state = const DeckActionsState(busy: true);
    try {
      await ref.read(deckRepositoryProvider).delete(deckId);
      if (ref.mounted) state = const DeckActionsState();
      return true;
    } catch (e) {
      if (ref.mounted) state = DeckActionsState(error: _asAppError(e));
      return false;
    }
  }

  AppError _asAppError(Object e) => e is AppError
      ? e
      : UnexpectedError('Колода $deckId: неожиданная ошибка', cause: e);
}

final deckActionsProvider = NotifierProvider.autoDispose
    .family<DeckActionsNotifier, DeckActionsState, String>(
      DeckActionsNotifier.new,
    );
