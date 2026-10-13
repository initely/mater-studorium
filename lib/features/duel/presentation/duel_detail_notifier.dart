import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/duel_providers.dart';
import '../domain/duel.dart';

/// Одна дуэль на экране состояния. `null` — дуэли нет или пользователь не
/// участник (сервер отвечает одинаково).
class DuelDetailNotifier extends AsyncNotifier<Duel?> {
  DuelDetailNotifier(this.duelId);

  final String duelId;

  @override
  Future<Duel?> build() => ref.watch(duelRepositoryProvider).get(duelId);

  Future<void> refresh() async {
    final result = await AsyncValue.guard(
      () => ref.read(duelRepositoryProvider).get(duelId),
    );
    if (!ref.mounted) return;
    if (result.hasError && state.hasValue) return;
    state = result;
  }
}

final duelDetailProvider = AsyncNotifierProvider.autoDispose
    .family<DuelDetailNotifier, Duel?, String>(DuelDetailNotifier.new);
