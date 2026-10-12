import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../session/data/session_providers.dart';
import '../domain/home_stats.dart';

/// Что нужно главному экрану: есть ли скачанные колоды и, если есть,
/// счётчики.
class HomeState {
  const HomeState({required this.deckCount, this.stats});

  final int deckCount;

  /// `null`, если колод нет (считать нечего).
  final HomeStats? stats;
}

/// Счётчики главного экрана. Пересчитывается при смене скачанных колод и
/// настроек (watch) и по запросу экрана ([refresh]): после возвращения из
/// сессии и при возврате в приложение, так как `due` наступает со временем.
/// Ошибка хранилища остаётся в `AsyncError`, экран показывает «Повторить».
class HomeNotifier extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    final decks = await ref.watch(downloadedDecksProvider.future);
    final settings = ref.watch(sessionSettingsProvider);
    if (decks.isEmpty) return const HomeState(deckCount: 0);
    final stats = await HomeStatsCalculator(
      repository: ref.watch(sessionRepositoryProvider),
      builder: ref.watch(sessionQueueBuilderProvider),
    ).compute(now: ref.read(clockProvider)(), settings: settings);
    return HomeState(deckCount: decks.length, stats: stats);
  }

  void refresh() => ref.invalidateSelf();
}

final homeProvider = AsyncNotifierProvider.autoDispose<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
