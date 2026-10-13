import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/app/router.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/data/catalog_providers.dart';
import 'package:mater_studorium/features/duel/data/duel_providers.dart';
import 'package:mater_studorium/features/duel/presentation/duel_create_screen.dart';
import 'package:mater_studorium/features/duel/presentation/duel_hub_screen.dart';
import 'package:mater_studorium/features/duel/presentation/duel_join_screen.dart';
import 'package:mater_studorium/features/duel/presentation/duel_screen.dart';

import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_duel_repository.dart';
import '../../../helpers/pump_app.dart';

/// Экраны дуэлей на настоящем роутере с теми же адресами, что в приложении;
/// `/` и `/decks` — заглушки. Возвращает роутер, чтобы тест мог смотреть адрес.
Future<GoRouter> pumpDuelApp(
  WidgetTester tester, {
  required String initial,
  required FakeDuelRepository repo,
  FakeDuelQuestionSource? source,
  FakeCatalogRepository? catalog,
  DateTime? now,
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('экран-главный')),
      GoRoute(path: '/decks', builder: (_, _) => const Text('экран-колоды')),
      GoRoute(
        path: '/duels',
        builder: (_, _) => const DuelHubScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const DuelCreateScreen()),
          GoRoute(path: 'join', builder: (_, _) => const DuelJoinScreen()),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                DuelScreen(duelId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  var uuids = 0;
  await tester.pumpRouterApp(
    overrides: [
      routerProvider.overrideWithValue(router),
      duelRepositoryProvider.overrideWithValue(repo),
      duelQuestionSourceProvider.overrideWithValue(
        source ?? FakeDuelQuestionSource(),
      ),
      catalogRepositoryProvider.overrideWithValue(
        catalog ?? FakeCatalogRepository(),
      ),
      clockProvider.overrideWithValue(() => now ?? duelNow),
      uuidGeneratorProvider.overrideWithValue(() => 'duel-uuid-${++uuids}'),
      randomProvider.overrideWithValue(math.Random(1)),
    ],
  );
  await tester.pumpAndSettle();
  return router;
}

/// Перехватывает буфер обмена: возвращает список скопированных строк.
List<String> captureClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

/// Размер по ключу: тап-цели не меньше 48 dp.
void expectTapTarget(WidgetTester tester, Key key) {
  final size = tester.getSize(find.byKey(key));
  expect(size.height, greaterThanOrEqualTo(48), reason: '$key: $size');
  expect(size.width, greaterThanOrEqualTo(48), reason: '$key: $size');
}
