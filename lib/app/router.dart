import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/catalog/presentation/decks_screen.dart';
import '../features/settings/presentation/settings_placeholder.dart';
import 'home_placeholder.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePlaceholder()),
      GoRoute(path: '/decks', builder: (context, state) => const DecksScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPlaceholder(),
      ),
    ],
  ),
);
