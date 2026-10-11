import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mater_studorium/features/catalog/data/catalog_providers.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';

import '../helpers/fake_catalog_repository.dart';
import '../helpers/fake_session_repository.dart';
import '../helpers/pump_app.dart';
import '../helpers/unmount_app.dart';

void main() {
  testWidgets('Home -> Settings navigation', (tester) async {
    await tester.pumpRouterApp();
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('На главную'), findsOneWidget);
  });

  testWidgets('Home -> Колоды -> назад', (tester) async {
    final repo = FakeCatalogRepository(remote: [remoteDeck('a')]);
    await tester.pumpRouterApp(
      overrides: [catalogRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Колоды'));
    await tester.pumpAndSettle();
    expect(find.text('Колода a'), findsOneWidget);
    expect(find.text('Скачать'), findsOneWidget);

    // pageBack ищет подсказку «Back», а локаль ru даёт «Назад».
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('Home -> Начать сессию -> экран сессии -> крестик -> Home', (
    tester,
  ) async {
    await tester.pumpRouterApp(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать сессию'));
    await tester.pumpAndSettle();
    // Колод нет: пустое состояние сессии.
    expect(find.text('Пока нечего повторять'), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-close')));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsOneWidget);
  });
}
