import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../data/catalog_providers.dart';
import 'catalog_state.dart';

/// Экран «Колоды»: каталог сервера, скачанные колоды и скачивание/обновление.
/// Ошибки репозитория превращаются в состояние, наружу не бросаются.
class CatalogNotifier extends Notifier<CatalogState> {
  @override
  CatalogState build() {
    final repository = ref.watch(catalogRepositoryProvider);
    final sub = repository.watchDownloaded().listen(
      (local) => state = state.copyWith(local: local),
    );
    ref.onDispose(sub.cancel);
    // Не из build: refresh() сразу меняет state.
    scheduleMicrotask(refresh);
    return const CatalogState(loading: true);
  }

  /// Перечитывает каталог сервера. Без сети остаются скачанные колоды и
  /// сообщение об ошибке.
  Future<void> refresh() async {
    state = state.copyWith(loading: true, listError: () => null);
    try {
      final remote = await ref.read(catalogRepositoryProvider).list();
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, remote: remote);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, listError: () => _asAppError(e));
    }
  }

  /// Скачивает колоду или обновляет её до версии сервера.
  Future<void> download(String deckId) async {
    if (state.downloading.contains(deckId)) return;
    state = state.copyWith(
      downloading: {...state.downloading, deckId},
      deckErrors: {...state.deckErrors}..remove(deckId),
    );
    AppError? failure;
    try {
      await ref.read(catalogRepositoryProvider).download(deckId);
    } catch (e) {
      failure = _asAppError(e);
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      downloading: {...state.downloading}..remove(deckId),
      deckErrors: failure == null
          ? state.deckErrors
          : {...state.deckErrors, deckId: failure},
    );
  }

  /// Репозиторий обязан отдавать [AppError]; всё прочее — страховка, чтобы
  /// сырое исключение не дошло до UI.
  AppError _asAppError(Object e) => e is AppError
      ? e
      : UnexpectedError('Каталог: неожиданная ошибка', cause: e);
}

final catalogProvider = NotifierProvider<CatalogNotifier, CatalogState>(
  CatalogNotifier.new,
);
