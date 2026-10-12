import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/home/presentation/home_screen.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/domain/session_repository.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/unmount_app.dart';

/// Репозиторий, у которого чтение due падает (ошибка локальной БД).
class _FailingRepository extends FakeSessionRepository {
  _FailingRepository({super.contents});

  bool failing = true;

  @override
  Future<List<ItemState>> dueStates({
    required DateTime now,
    Set<String>? deckIds,
  }) async {
    if (failing) throw const LocalStorageError('диск');
    return super.dueStates(now: now, deckIds: deckIds);
  }
}

Future<void> pumpHome(
  WidgetTester tester, {
  required SessionRepository session,
  bool withDeck = true,
}) async {
  final db = memoryDb();
  await markOnboarded(db);
  await tester.pumpApp(
    const HomeScreen(),
    overrides: [
      ...appOverrides(
        db,
        catalog: FakeCatalogRepository(
          local: withDeck ? [localDeck('d1')] : const [],
        ),
      ),
      sessionRepositoryProvider.overrideWithValue(session),
    ],
  );
  await tester.pumpAndSettle();
}

String statValue(WidgetTester tester, String key) {
  final text = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(text.at(0)).data!;
}

void main() {
  testWidgets('нет колод: призыв скачать, кнопки сессии нет (ТЗ §8.5)', (
    tester,
  ) async {
    await pumpHome(tester, session: FakeSessionRepository(), withDeck: false);

    expect(find.byKey(const Key('home-no-decks')), findsOneWidget);
    expect(find.text('Пока нет колод'), findsOneWidget);
    expect(find.byKey(const Key('home-download')), findsOneWidget);
    expect(find.byKey(const Key('home-start-session')), findsNothing);
    // Переход в колоды и настройки доступен всегда.
    expect(find.byKey(const Key('home-decks')), findsOneWidget);
    expect(find.byKey(const Key('home-settings')), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('есть что повторять: счётчики и «Начать сессию (5 мин)»', (
    tester,
  ) async {
    final session = FakeSessionRepository(
      contents: [
        for (final id in ['a', 'b', 'c', 'n1', 'n2']) fakeContent(id),
      ],
      states: {
        for (final id in ['a', 'b', 'c'])
          id: fakeState(id, fakeNow.subtract(const Duration(hours: 1))),
      },
    );
    await pumpHome(tester, session: session);

    expect(statValue(tester, 'home-stat-due'), '3');
    expect(statValue(tester, 'home-stat-new'), '2');
    expect(find.text('знания к повторению'), findsOneWidget);
    expect(find.text('новых знания'), findsOneWidget);
    expect(find.text('Начать сессию (5 мин)'), findsOneWidget);
    expect(find.byKey(const Key('home-all-done')), findsNothing);

    // Тап-цели: главная кнопка и кнопка колод не меньше 48 dp.
    for (final key in ['home-start-session', 'home-decks', 'home-settings']) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
    await tester.unmountApp();
  });

  testWidgets('новых больше лимита дня: показан остаток лимита', (
    tester,
  ) async {
    final session = FakeSessionRepository(
      contents: [for (var i = 0; i < 20; i++) fakeContent('n$i')],
      logs: [
        // Два знания уже впервые показаны сегодня, лимит по умолчанию 10.
        fakeLog('x1', fakeNow),
        fakeLog('x2', fakeNow),
      ],
    );
    await pumpHome(tester, session: session);

    expect(statValue(tester, 'home-stat-due'), '0');
    expect(statValue(tester, 'home-stat-new'), '8');
    await tester.unmountApp();
  });

  testWidgets('всё повторено: следующее через 3 ч, без кнопки сессии', (
    tester,
  ) async {
    final session = FakeSessionRepository(
      contents: [fakeContent('a')],
      states: {'a': fakeState('a', fakeNow.add(const Duration(hours: 3)))},
      // Единственное знание уже показано: новых нет.
    );
    await pumpHome(tester, session: session);

    expect(find.byKey(const Key('home-all-done')), findsOneWidget);
    expect(find.text('Всё повторено 🎉'), findsOneWidget);
    expect(find.text('Следующее повторение — через 3 ч'), findsOneWidget);
    expect(find.byKey(const Key('home-start-session')), findsNothing);
    expect(find.byKey(const Key('home-take-new')), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('лимит новых исчерпан: «Взять 5 новых»', (tester) async {
    final session = FakeSessionRepository(
      contents: [for (var i = 0; i < 15; i++) fakeContent('n$i')],
      logs: [for (var i = 0; i < 10; i++) fakeLog('x$i', fakeNow)],
    );
    await pumpHome(tester, session: session);

    expect(find.byKey(const Key('home-all-done')), findsOneWidget);
    expect(
      find.text('На сегодня лимит новых знаний исчерпан.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-take-new')), findsOneWidget);
    expect(find.text('Взять 5 новых'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('в колодах нет доступных знаний: нейтральное сообщение', (
    tester,
  ) async {
    await pumpHome(tester, session: FakeSessionRepository());

    expect(find.byKey(const Key('home-nothing')), findsOneWidget);
    expect(find.text('Здесь пока нечего повторять'), findsOneWidget);
    expect(find.byKey(const Key('home-start-session')), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('ошибка хранилища: сообщение и «Повторить» пересчитывает', (
    tester,
  ) async {
    final session = _FailingRepository(contents: [fakeContent('n1')]);
    await pumpHome(tester, session: session);

    expect(find.byKey(const Key('home-error')), findsOneWidget);
    expect(find.byKey(const Key('home-start-session')), findsNothing);
    // Переход в колоды доступен и при ошибке.
    expect(find.byKey(const Key('home-decks')), findsOneWidget);

    session.failing = false;
    await tester.tap(find.byKey(const Key('home-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-error')), findsNothing);
    expect(statValue(tester, 'home-stat-new'), '1');
    await tester.unmountApp();
  });

  testWidgets('озвучка счётчиков: одна строка с числами', (tester) async {
    final handle = tester.ensureSemantics();
    final session = FakeSessionRepository(
      contents: [fakeContent('a'), fakeContent('n1')],
      states: {'a': fakeState('a', fakeNow.subtract(const Duration(hours: 1)))},
    );
    await pumpHome(tester, session: session);

    expect(find.bySemanticsLabel('К повторению: 1, новых: 1'), findsOneWidget);
    handle.dispose();
    await tester.unmountApp();
  });
}
