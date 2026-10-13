import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/duel_providers.dart';
import '../domain/duel.dart';

/// Дуэли пользователя для списка на экране «Дуэли». Читаются с сервера при
/// открытии и по `refresh()`; офлайн-копии нет (дуэль в основном серверное
/// состояние, она не влияет на FSRS, ADR-16).
class MyDuelsNotifier extends AsyncNotifier<List<Duel>> {
  @override
  Future<List<Duel>> build() => ref.watch(duelRepositoryProvider).mine();

  Future<void> refresh() async {
    final result = await AsyncValue.guard(
      () => ref.read(duelRepositoryProvider).mine(),
    );
    if (!ref.mounted) return;
    // Ошибка обновления не стирает прежний список.
    if (result.hasError && state.hasValue) return;
    state = result;
  }
}

final myDuelsProvider =
    AsyncNotifierProvider.autoDispose<MyDuelsNotifier, List<Duel>>(
      MyDuelsNotifier.new,
    );
