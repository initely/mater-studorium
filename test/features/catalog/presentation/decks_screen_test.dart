import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/data/catalog_providers.dart';
import 'package:mater_studorium/features/catalog/presentation/decks_screen.dart';

import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/unmount_app.dart';

Future<void> _pump(WidgetTester tester, FakeCatalogRepository repo) async {
  await tester.pumpApp(
    const DecksScreen(),
    overrides: [catalogRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  testWidgets('пока каталог грузится, виден индикатор', (tester) async {
    final repo = FakeCatalogRepository(remote: [remoteDeck('a')]);
    await _pump(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('три состояния колоды: скачать, скачано, обновить', (
    tester,
  ) async {
    final repo = FakeCatalogRepository(
      remote: [
        remoteDeck('new', items: 1),
        remoteDeck('same', version: 2, items: 5),
        remoteDeck('old', version: 3, items: 22),
      ],
      local: [localDeck('same', version: 2), localDeck('old', version: 1)],
    );
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Колоды'), findsOneWidget); // заголовок
    // «Скачать».
    expect(
      find.descendant(
        of: find.byKey(const Key('deck-action-new')),
        matching: find.text('Скачать'),
      ),
      findsOneWidget,
    );
    expect(find.text('infosec · версия 1 · 1 знание'), findsOneWidget);
    // «Скачано» (версия не новее).
    expect(
      find.descendant(
        of: find.byKey(const Key('deck-action-same')),
        matching: find.text('Скачано'),
      ),
      findsOneWidget,
    );
    expect(find.text('infosec · версия 2 · 5 знаний'), findsOneWidget);
    // «Обновить» (на сервере новее).
    expect(
      find.descendant(
        of: find.byKey(const Key('deck-action-old')),
        matching: find.text('Обновить'),
      ),
      findsOneWidget,
    );
    expect(find.text('infosec · версия 3 · 22 знания'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('скачивание: «Загрузка…» блокирует кнопку, затем «Скачано»', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repo = FakeCatalogRepository(remote: [remoteDeck('a')])
      ..downloadGate = gate;
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Скачать'));
    await tester.pump();

    expect(find.text('Загрузка…'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('deck-action-a')),
    );
    expect(button.onPressed, isNull);
    expect(repo.downloads, ['a']);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Скачано'), findsOneWidget);
    expect(find.text('Скачать'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('обновление: «Обновить» → «Скачано»', (tester) async {
    final repo = FakeCatalogRepository(
      remote: [remoteDeck('a', version: 2)],
      local: [localDeck('a', version: 1)],
    );
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();

    expect(repo.downloads, ['a']);
    expect(find.text('Скачано'), findsOneWidget);
    expect(find.text('Обновить'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('нет сети и ничего не скачано: сообщение и «Повторить»', (
    tester,
  ) async {
    final repo = FakeCatalogRepository()..listError = const NetworkError('x');
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('decks-list-error')), findsOneWidget);
    expect(find.textContaining('нужна сеть'), findsOneWidget);
    expect(find.text('Колод пока нет'), findsNothing);

    // Сеть вернулась: «Повторить» подгружает каталог.
    repo
      ..listError = null
      ..remote = [remoteDeck('a')];
    await tester.tap(find.byKey(const Key('decks-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('decks-list-error')), findsNothing);
    expect(find.text('Скачать'), findsOneWidget);
    expect(repo.listCalls, 2);
    await tester.unmountApp();
  });

  testWidgets('нет сети, но есть скачанные колоды: они показаны', (
    tester,
  ) async {
    final repo = FakeCatalogRepository(local: [localDeck('a', version: 4)])
      ..listError = const NetworkError('x');
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('decks-list-error')), findsOneWidget);
    expect(find.text('Колода a'), findsOneWidget);
    expect(find.text('Скачано'), findsOneWidget);
    expect(find.text('infosec · версия 4'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets(
    'неожиданная ошибка списка: общий текст без технических подробностей',
    (tester) async {
      final repo = FakeCatalogRepository()
        ..listError = StateError('исключение Supabase');
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Не удалось загрузить каталог'),
        findsOneWidget,
      );
      expect(find.textContaining('Supabase'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      await tester.unmountApp();
    },
  );

  testWidgets('каталог пуст', (tester) async {
    await _pump(tester, FakeCatalogRepository());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('decks-empty')), findsOneWidget);
    expect(find.text('Колод пока нет'), findsOneWidget);
    await tester.unmountApp();
  });

  group('ошибки скачивания остаются на карточке колоды', () {
    final cases = <(String, Object, String)>[
      ('сеть', const NetworkError('x'), 'Нужна сеть, чтобы скачать колоду'),
      (
        'повреждённый файл',
        const DeckFormatError('x'),
        'Файл колоды повреждён, колода не изменена',
      ),
      (
        'новый формат',
        const DeckSchemaTooNewError(9, 1),
        'Колоде нужна более новая версия приложения. Обновите приложение.',
      ),
      (
        'коллизия item_id',
        const ItemIdCollisionError('i', 'other'),
        'Колода конфликтует с уже скачанной: одно и то же знание есть в обеих',
      ),
      (
        'нет на сервере',
        const DeckNotFoundError('a'),
        'Колода не найдена на сервере',
      ),
      (
        'вход отклонён',
        const AuthError('x'),
        'Не удалось скачать колоду. Попробуйте ещё раз.',
      ),
      (
        'сырое исключение',
        StateError('PostgrestException'),
        'Не удалось скачать колоду. Попробуйте ещё раз.',
      ),
    ];
    for (final (name, error, text) in cases) {
      testWidgets(name, (tester) async {
        final repo = FakeCatalogRepository(remote: [remoteDeck('a')])
          ..downloadError = error;
        await _pump(tester, repo);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Скачать'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('deck-error-a')), findsOneWidget);
        expect(find.text(text), findsOneWidget);
        // Колода не скачана, кнопка снова доступна.
        expect(find.text('Скачать'), findsOneWidget);
        expect(find.textContaining('Postgrest'), findsNothing);

        // Повторная попытка очищает ошибку.
        repo.downloadError = null;
        await tester.tap(find.text('Скачать'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('deck-error-a')), findsNothing);
        expect(find.text('Скачано'), findsOneWidget);
        await tester.unmountApp();
      });
    }
  });
}
