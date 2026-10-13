import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/isolate_name.dart';

import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_duel_repository.dart';
import 'duel_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

void main() {
  testWidgets('создатель ждёт соперника: статус, срок, код', (tester) async {
    final copied = captureClipboard(tester);
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: FakeDuelRepository()..getResult = duelFixture(),
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
    );
    expect(find.text('Ждём соперника'), findsOneWidget);
    expect(find.text('осталось 3 д'), findsOneWidget);
    expect(find.text('K7Q 2MX'), findsOneWidget);
    expect(_key('duel-deck-missing'), findsNothing);
    await tester.tap(_key('duel-copy-code'));
    await tester.pump();
    expect(copied, ['K7Q2MX']);
  });

  testWidgets('соперник вошёл: имя в статусе, кода уже нет у соперника', (
    tester,
  ) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: FakeDuelRepository()
        ..getResult = duelFixture(
          code: null,
          isCreator: false,
          otherJoined: true,
          otherName: 'Алиса',
          status: DuelStatus.active,
        ),
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
    );
    expect(find.text('${isolateName('Алиса')} в дуэли'), findsOneWidget);
    expect(_key('duel-copy-code'), findsNothing);
  });

  testWidgets('код показывается только создателю, даже если пришёл не ему', (
    tester,
  ) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: FakeDuelRepository()
        ..getResult = duelFixture(
          code: 'K7Q2MX',
          isCreator: false,
          otherJoined: true,
          status: DuelStatus.active,
        ),
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
    );
    expect(_key('duel-code'), findsNothing);
    expect(_key('duel-copy-code'), findsNothing);
  });

  testWidgets('без имени соперника — нейтральный статус', (tester) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: FakeDuelRepository()
        ..getResult = duelFixture(otherJoined: true, status: DuelStatus.active),
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
    );
    expect(find.text('Соперник в дуэли'), findsOneWidget);
  });

  testWidgets('срок вышел по часам клиента: статус «истекла», кода нет', (
    tester,
  ) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: FakeDuelRepository()..getResult = duelFixture(),
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
      now: duelNow.add(const Duration(hours: 73)),
    );
    expect(find.text('Дуэль истекла'), findsOneWidget);
    expect(_key('duel-code'), findsNothing);
    expect(_key('duel-remaining'), findsNothing);
    expect(_key('duel-deck-missing'), findsNothing);
  });

  testWidgets('завершённая дуэль', (tester) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: FakeDuelRepository()
        ..getResult = duelFixture(
          status: DuelStatus.finished,
          otherJoined: true,
          otherName: 'Боб',
          myDoneAt: duelNow,
          otherDoneAt: duelNow,
        ),
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
    );
    expect(find.text('Дуэль завершена'), findsOneWidget);
    expect(_key('duel-code'), findsNothing);
  });

  testWidgets('остаток срока: часы и минуты', (tester) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: FakeDuelRepository()..getResult = duelFixture(),
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
      now: duelNow.add(const Duration(hours: 66, minutes: 30)),
    );
    expect(find.text('осталось 5 ч'), findsOneWidget);
  });

  testWidgets('дуэли нет или чужая: «Дуэль не найдена»', (tester) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/unknown',
      repo: FakeDuelRepository(),
    );
    expect(_key('duel-not-found'), findsOneWidget);
  });

  testWidgets('ошибка загрузки и повтор', (tester) async {
    final repo = FakeDuelRepository()..getError = const NetworkError('x');
    await pumpDuelApp(tester, initial: '/duels/duel-1', repo: repo);
    expect(_key('duel-error'), findsOneWidget);
    repo
      ..getError = null
      ..getResult = duelFixture();
    await tester.tap(_key('duel-retry'));
    await tester.pumpAndSettle();
    expect(_key('duel-error'), findsNothing);
    expect(find.text('Ждём соперника'), findsOneWidget);
  });

  testWidgets('кнопка «Обновить» перечитывает состояние', (tester) async {
    final repo = FakeDuelRepository()..getResult = duelFixture();
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: repo,
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
    );
    expect(repo.getCalls, 1);
    repo.getResult = duelFixture(
      otherJoined: true,
      otherName: 'Боб',
      status: DuelStatus.active,
    );
    expectTapTarget(tester, const Key('duel-refresh'));
    await tester.tap(_key('duel-refresh'));
    await tester.pumpAndSettle();
    expect(repo.getCalls, 2);
    expect(find.text('${isolateName('Боб')} в дуэли'), findsOneWidget);
  });

  testWidgets('ошибка обновления не стирает показанную дуэль', (tester) async {
    final repo = FakeDuelRepository()..getResult = duelFixture();
    await pumpDuelApp(
      tester,
      initial: '/duels/duel-1',
      repo: repo,
      catalog: FakeCatalogRepository(
        local: [localDeck('fixture-good', version: 2)],
      ),
    );
    repo.getError = const NetworkError('x');
    await tester.tap(_key('duel-refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Ждём соперника'), findsOneWidget);
    expect(_key('duel-error'), findsNothing);
  });

  group('колода дуэли', () {
    testWidgets('нет на устройстве: карточка и докачка', (tester) async {
      final catalog = FakeCatalogRepository(
        remote: [remoteDeck('fixture-good', version: 2)],
      );
      await pumpDuelApp(
        tester,
        initial: '/duels/duel-1',
        repo: FakeDuelRepository()..getResult = duelFixture(),
        catalog: catalog,
      );
      expect(_key('duel-deck-missing'), findsOneWidget);
      await tester.ensureVisible(_key('duel-deck-download'));
      await tester.pumpAndSettle();
      expectTapTarget(tester, const Key('duel-deck-download'));
      await tester.tap(_key('duel-deck-download'));
      await tester.pumpAndSettle();
      expect(catalog.downloads, ['fixture-good']);
      expect(_key('duel-deck-missing'), findsNothing);
    });

    testWidgets('версия на устройстве старее версии дуэли: докачка', (
      tester,
    ) async {
      await pumpDuelApp(
        tester,
        initial: '/duels/duel-1',
        repo: FakeDuelRepository()..getResult = duelFixture(deckVersion: 3),
        catalog: FakeCatalogRepository(
          remote: [remoteDeck('fixture-good', version: 3)],
          local: [localDeck('fixture-good', version: 2)],
        ),
      );
      expect(_key('duel-deck-missing'), findsOneWidget);
    });

    testWidgets('сбой докачки: сообщение, можно повторить', (tester) async {
      final catalog = FakeCatalogRepository(
        remote: [remoteDeck('fixture-good', version: 2)],
      )..downloadError = const NetworkError('x');
      await pumpDuelApp(
        tester,
        initial: '/duels/duel-1',
        repo: FakeDuelRepository()..getResult = duelFixture(),
        catalog: catalog,
      );
      await tester.ensureVisible(_key('duel-deck-download'));
      await tester.pumpAndSettle();
      await tester.tap(_key('duel-deck-download'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('duel-deck-error'));
      expect(_key('duel-deck-error'), findsOneWidget);
      catalog.downloadError = null;
      await tester.tap(_key('duel-deck-download'));
      await tester.pumpAndSettle();
      expect(_key('duel-deck-missing'), findsNothing);
    });
  });
}
