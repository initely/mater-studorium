import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../auth/presentation/auth_session_notifier.dart';
import '../data/catalog_providers.dart';
import 'catalog_state.dart';

/// Сколько ждать завершения анонимного входа перед запросом каталога. Без
/// входа сервер каталога отвечает отказом, который пользователь увидел бы как
/// «нужна сеть» (POLISH п. 1). Дольше ждать нет смысла: без сети вход не
/// завершится, и честнее показать ошибку с «Повторить».
const catalogSessionWait = Duration(seconds: 20);

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
    // Повтор после сбоя инициализации Supabase (POLISH п. 3): пробуем её ещё
    // раз; при успехе провайдеры пересоздаются и `build` сам запросит список.
    if (ref.read(supabaseStatusProvider) != SupabaseStatus.ready) {
      final ready = await ref
          .read(supabaseStatusProvider.notifier)
          .ensureInitialized();
      if (!ref.mounted || ready) return;
    }
    await _waitForSession();
    if (!ref.mounted) return;
    try {
      final remote = await ref.read(catalogRepositoryProvider).list();
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, remote: remote);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, listError: () => _asAppError(e));
    }
  }

  /// Ждёт, пока завершится анонимный вход (или выйдет [catalogSessionWait]).
  /// Входа нет и не ожидается (бэкенд недоступен, сервер отказал) — не ждёт.
  Future<void> _waitForSession() async {
    if (ref.read(supabaseStatusProvider) != SupabaseStatus.ready) return;
    if (ref.read(authSessionProvider) != AuthSessionStatus.signingIn) return;
    final done = Completer<void>();
    final sub = ref.listen(authSessionProvider, (_, next) {
      if (next != AuthSessionStatus.signingIn && !done.isCompleted) {
        done.complete();
      }
    });
    final timer = Timer(catalogSessionWait, () {
      if (!done.isCompleted) done.complete();
    });
    try {
      await done.future;
    } finally {
      timer.cancel();
      sub.close();
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
