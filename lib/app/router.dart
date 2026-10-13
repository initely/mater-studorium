import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/catalog/presentation/decks_screen.dart';
import '../features/deck/presentation/deck_screen.dart';
import '../features/duel/presentation/duel_create_screen.dart';
import '../features/duel/presentation/duel_hub_screen.dart';
import '../features/duel/presentation/duel_join_screen.dart';
import '../features/duel/presentation/duel_play_screen.dart';
import '../features/duel/presentation/duel_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/session/presentation/session_screen.dart';
import '../features/settings/presentation/settings_notifier.dart';
import '../features/settings/presentation/settings_screen.dart';

const _kHome = '/';
const _kOnboarding = '/onboarding';
const _kLoading = '/loading';

/// Роутер с редиректом на онбординг (T18).
///
/// Флаг «онбординг пройден» лежит в локальной БД и читается асинхронно.
/// `main` ждёт настройки до первого кадра, поэтому на холодном старте
/// роутер уже знает ответ и ничего не мигает. Если настройки всё же ещё
/// грузятся (тесты, медленное хранилище), показывается нейтральный экран
/// `/loading`, а после загрузки роутер возвращает на запрошенный адрес
/// (параметр `from`). Ошибка чтения настроек считается «онбординг не пройден»:
/// он безвреден, а флаг запишется при завершении.
final routerProvider = Provider<GoRouter>((ref) {
  // Роутер не пересоздаётся при смене настроек: только перепроверяет
  // редирект, когда меняется флаг онбординга или статус загрузки.
  final refresh = ValueNotifier<int>(0);
  ref.listen(settingsProvider, (previous, next) {
    final changed =
        previous?.isLoading != next.isLoading ||
        previous?.value?.onboardingDone != next.value?.onboardingDone;
    if (changed) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final location = state.matchedLocation;
      if (settings.isLoading && !settings.hasValue) {
        return location == _kLoading
            ? null
            : Uri(
                path: _kLoading,
                queryParameters: {'from': state.uri.toString()},
              ).toString();
      }
      final done = settings.value?.onboardingDone ?? false;
      if (location == _kLoading) {
        final from = state.uri.queryParameters['from'];
        return from == null || from.startsWith(_kLoading) ? _kHome : from;
      }
      if (!done && location != _kOnboarding) return _kOnboarding;
      if (done && location == _kOnboarding) return _kHome;
      return null;
    },
    routes: [
      GoRoute(path: _kHome, builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: _kLoading,
        builder: (context, state) => const Scaffold(body: SizedBox.expand()),
      ),
      GoRoute(
        path: _kOnboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/decks',
        builder: (context, state) => const DecksScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                DeckScreen(deckId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/duels',
        builder: (context, state) => const DuelHubScreen(),
        routes: [
          // Статические сегменты раньше ':id', иначе `new` разберётся как id.
          GoRoute(
            path: 'new',
            builder: (context, state) => const DuelCreateScreen(),
          ),
          GoRoute(
            path: 'join',
            builder: (context, state) => const DuelJoinScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                DuelScreen(duelId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'play',
                builder: (context, state) =>
                    DuelPlayScreen(duelId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) => SessionScreen(
          // Ключ по запросу: новая сессия по другой колоде не наследует
          // состояние предыдущей.
          key: ValueKey(state.uri.toString()),
          deckId: state.uri.queryParameters['deck'],
          extraNew:
              int.tryParse(state.uri.queryParameters['extraNew'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
