// Карточки дуэлей на главном (T23, ТЗ §8.4): «твой ход», «ждём», «результат».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/app/router.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/data/duel_providers.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/isolate_name.dart';
import 'package:mater_studorium/features/home/presentation/home_screen.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/duel_fixtures.dart';
import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_duel_repository.dart';
import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/unmount_app.dart';

Finder _key(String key) => find.byKey(Key(key));

void main() {
  late FakeDuelRepository repo;
  late FakeDuelSeenStore seen;

  setUp(() {
    repo = FakeDuelRepository();
    seen = FakeDuelSeenStore();
  });

  Future<GoRouter> pumpHome(WidgetTester tester) async {
    final db = memoryDb();
    await markOnboarded(db);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/duels/:id',
          builder: (_, state) => Text('дуэль ${state.pathParameters['id']}'),
        ),
        GoRoute(path: '/duels', builder: (_, _) => const Text('экран-дуэли')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpRouterApp(
      overrides: [
        ...appOverrides(
          db,
          now: duelNow,
          catalog: FakeCatalogRepository(local: [localDeck('d1')]),
        ),
        routerProvider.overrideWithValue(router),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        duelRepositoryProvider.overrideWithValue(repo),
        duelSeenStoreProvider.overrideWithValue(seen),
      ],
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('нет дуэлей: блока нет, кнопка «Дуэли» на месте', (tester) async {
    await pumpHome(tester);
    expect(_key('home-duel-cards'), findsNothing);
    expect(_key('home-duels'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('твой ход, ждём, результат: порядок, подписи, срок', (
    tester,
  ) async {
    repo.mineResult = [
      // Ждём: я закончил, соперник нет (новые первыми).
      playDuel(
        id: 'wait',
        myDoneAt: duelNow,
        otherName: 'Боб',
      ).copyWith(createdAt: duelNow.subtract(const Duration(hours: 1))),
      // Результат: оба закончили, не открывался.
      playDuel(
        id: 'res',
        status: DuelStatus.finished,
        myDoneAt: duelNow,
        otherDoneAt: duelNow,
        otherName: 'Вика',
      ),
      // Твой ход.
      playDuel(id: 'turn', otherName: 'Алиса'),
    ];
    await pumpHome(tester);
    final cards = [
      for (final w in tester.widgetList(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${w.key}'.contains('home-duel-') &&
              !'${w.key}'.contains('cards'),
        ),
      ))
        (w.key! as ValueKey<String>).value,
    ];
    expect(cards, ['home-duel-turn', 'home-duel-res', 'home-duel-wait']);

    expect(find.text('${isolateName('Алиса')}: твой ход'), findsOneWidget);
    expect(
      find.text('${isolateName('Вика')} ответил: посмотри результат'),
      findsOneWidget,
    );
    expect(find.text('${isolateName('Боб')}: ждём ответа'), findsOneWidget);
    expect(
      find.text('осталось 3 д'),
      findsNWidgets(2),
      reason: 'у результата срока нет',
    );
    await tester.unmountApp();
  });

  testWidgets('без имени соперника: нейтральные подписи', (tester) async {
    repo.mineResult = [
      playDuel(id: 'a', otherName: null),
      playDuel(id: 'b', myDoneAt: duelNow, otherName: null),
      playDuel(
        id: 'c',
        status: DuelStatus.finished,
        myDoneAt: duelNow,
        otherDoneAt: duelNow,
        otherName: null,
      ),
    ];
    await pumpHome(tester);
    expect(find.text('Дуэль: твой ход'), findsOneWidget);
    expect(find.text('Дуэль: ждём соперника'), findsOneWidget);
    expect(find.text('Дуэль: посмотри результат'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('открытый результат и старый результат карточкой не висят', (
    tester,
  ) async {
    seen.seen.add('seen');
    repo.mineResult = [
      playDuel(
        id: 'seen',
        status: DuelStatus.finished,
        myDoneAt: duelNow,
        otherDoneAt: duelNow,
      ),
      playDuel(
        id: 'old',
        status: DuelStatus.finished,
        myDoneAt: duelNow.subtract(const Duration(days: 4)),
        otherDoneAt: duelNow.subtract(const Duration(days: 4)),
      ),
      playDuel(
        id: 'fresh',
        status: DuelStatus.finished,
        myDoneAt: duelNow.subtract(const Duration(days: 2)),
        otherDoneAt: duelNow.subtract(const Duration(days: 1)),
      ),
    ];
    await pumpHome(tester);
    expect(_key('home-duel-seen'), findsNothing);
    expect(_key('home-duel-old'), findsNothing);
    expect(_key('home-duel-fresh'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('истёкшая дуэль карточкой не показывается', (tester) async {
    repo.mineResult = [
      playDuel(id: 'gone').copyWith(
        createdAt: duelNow.subtract(const Duration(days: 4)),
        expiresAt: duelNow.subtract(const Duration(days: 1)),
      ),
    ];
    await pumpHome(tester);
    expect(_key('home-duel-cards'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('больше четырёх: показываются первые четыре по важности', (
    tester,
  ) async {
    repo.mineResult = [
      for (var i = 0; i < 6; i++) playDuel(id: 'w$i', myDoneAt: duelNow),
      playDuel(id: 'turn'),
    ];
    await pumpHome(tester);
    expect(_key('home-duel-turn'), findsOneWidget, reason: 'твой ход первым');
    expect(
      find.byWidgetPredicate(
        (w) => w.key is ValueKey && '${w.key}'.contains('home-duel-w'),
      ),
      findsNWidgets(3),
    );
    await tester.unmountApp();
  });

  testWidgets('нет сети: блока нет, главный работает', (tester) async {
    repo.mineError = const NetworkError('x');
    await pumpHome(tester);
    expect(_key('home-duel-cards'), findsNothing);
    expect(_key('home-duels'), findsOneWidget);
    expect(_key('home-error'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('тап по карточке открывает дуэль; тап-цель не меньше 48 dp', (
    tester,
  ) async {
    repo.mineResult = [playDuel(id: 'turn')];
    final router = await pumpHome(tester);
    final size = tester.getSize(_key('home-duel-turn'));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(_key('home-duel-turn'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/duels/turn');
    expect(find.text('дуэль turn'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('возврат на главный перечитывает карточки', (tester) async {
    repo.mineResult = [playDuel(id: 'turn')];
    final router = await pumpHome(tester);
    expect(_key('home-duel-turn'), findsOneWidget);
    await tester.tap(_key('home-duel-turn'));
    await tester.pumpAndSettle();
    // Пока были на экране дуэли, я ответил, и список поменялся.
    repo.mineResult = [playDuel(id: 'turn', myDoneAt: duelNow)];
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('${isolateName('Алиса')}: ждём ответа'), findsOneWidget);
    await tester.unmountApp();
  });
}
