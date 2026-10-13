import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/isolate_name.dart';

import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_duel_repository.dart';
import 'duel_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

const _notFound = 'Код не найден или дуэль истекла';

Future<void> _enterAndJoin(WidgetTester tester, String input) async {
  await tester.enterText(_key('duel-code-field'), input);
  await tester.tap(_key('duel-join-submit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('тап-цели; пока ничего не введено, ошибки нет', (tester) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/join',
      repo: FakeDuelRepository(),
    );
    expectTapTarget(tester, const Key('duel-join-submit'));
    expect(_key('duel-join-error'), findsNothing);
  });

  testWidgets(
    'успех: код нормализуется, колода докачивается, открывается экран дуэли',
    (tester) async {
      final repo = FakeDuelRepository()
        ..getResult = duelFixture(
          code: null,
          isCreator: false,
          otherJoined: true,
          otherName: 'Алиса',
          status: DuelStatus.active,
        );
      final catalog = FakeCatalogRepository(
        remote: [remoteDeck('fixture-good', version: 2)],
      );
      final router = await pumpDuelApp(
        tester,
        initial: '/duels/join',
        repo: repo,
        catalog: catalog,
      );
      await _enterAndJoin(tester, ' k7q 2mx ');
      expect(repo.joined, ['K7Q2MX']);
      expect(catalog.downloads, ['fixture-good']);
      expect(router.state.uri.path, '/duels/duel-1');
      expect(find.text('${isolateName('Алиса')} в дуэли'), findsOneWidget);
    },
  );

  testWidgets(
    'русская раскладка: похожие кириллические буквы не теряются и работают (N4)',
    (tester) async {
      final repo = FakeDuelRepository()
        ..getResult = duelFixture(
          code: null,
          isCreator: false,
          otherJoined: true,
        );
      final catalog = FakeCatalogRepository(
        remote: [remoteDeck('fixture-good', version: 2)],
      );
      await pumpDuelApp(
        tester,
        initial: '/duels/join',
        repo: repo,
        catalog: catalog,
      );
      // К7Q2МХ: К, М, Х набраны кириллицей.
      final typed = String.fromCharCodes([
        0x041A,
        0x37,
        0x51,
        0x32,
        0x041C,
        0x0425,
      ]);
      await tester.enterText(_key('duel-code-field'), typed);
      expect(
        tester.widget<TextField>(_key('duel-code-field')).controller!.text,
        typed,
        reason: 'ввод не должен молча теряться',
      );
      await tester.tap(_key('duel-join-submit'));
      await tester.pumpAndSettle();
      expect(repo.joined, ['K7Q2MX']);
    },
  );

  testWidgets(
    'неверная длина и запрещённые знаки: ошибка без запроса к серверу',
    (tester) async {
      final repo = FakeDuelRepository();
      await pumpDuelApp(tester, initial: '/duels/join', repo: repo);
      for (final bad in ['K7Q2M', 'K7Q2MXA', 'O7Q2MX', 'I7Q2MX', '07Q2MX']) {
        await _enterAndJoin(tester, bad);
        expect(find.text(_notFound), findsOneWidget, reason: bad);
      }
      expect(repo.joined, isEmpty);
    },
  );

  testWidgets('поле не принимает знаки вне букв и цифр', (tester) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/join',
      repo: FakeDuelRepository(),
    );
    await tester.enterText(_key('duel-code-field'), 'K7-Q2!MX');
    expect(
      tester.widget<TextField>(_key('duel-code-field')).controller!.text,
      'K7Q2MX',
    );
  });

  testWidgets('сервер: код не найден или просрочен — одно сообщение (AC10.2)', (
    tester,
  ) async {
    final repo = FakeDuelRepository()
      ..joinError = const DuelCodeNotFoundError();
    await pumpDuelApp(tester, initial: '/duels/join', repo: repo);
    await _enterAndJoin(tester, 'K7Q2MX');
    expect(find.text(_notFound), findsOneWidget);
    expect(repo.joined, ['K7Q2MX']);
  });

  group('другие ошибки', () {
    final cases = <(String, AppError, String)>[
      (
        'в дуэли уже есть соперник',
        const DuelFullError(),
        'В этой дуэли уже есть соперник',
      ),
      (
        'много неверных кодов',
        const DuelLimitError(DuelLimitKind.joinAttempts),
        'Слишком много неверных кодов. Подожди час и попробуй снова.',
      ),
      (
        'много активных дуэлей',
        const DuelLimitError(DuelLimitKind.activeDuels),
        'Слишком много активных дуэлей. Дождись окончания прежних.',
      ),
      (
        'нет сети',
        const NetworkError('x'),
        'Нужна сеть. Проверь подключение и повтори.',
      ),
      (
        'нет входа',
        const AuthError('x'),
        'Нет входа в аккаунт. Перезапусти приложение.',
      ),
    ];
    for (final (name, error, text) in cases) {
      testWidgets(name, (tester) async {
        final repo = FakeDuelRepository()..joinError = error;
        final router = await pumpDuelApp(
          tester,
          initial: '/duels/join',
          repo: repo,
        );
        await _enterAndJoin(tester, 'K7Q2MX');
        expect(find.text(text), findsOneWidget);
        expect(router.state.uri.path, '/duels/join');
        // Можно ввести другой код.
        expect(
          tester.widget<FilledButton>(_key('duel-join-submit')).onPressed,
          isNotNull,
        );
      });
    }
  });

  testWidgets('вход удался, а колоду скачать не вышло: дуэль открывается', (
    tester,
  ) async {
    final repo = FakeDuelRepository()
      ..getResult = duelFixture(
        code: null,
        isCreator: false,
        otherJoined: true,
        status: DuelStatus.active,
      );
    // Колоды нет на сервере каталога: download бросает не AppError, а мы всё
    // равно должны дойти до экрана дуэли только при AppError; здесь сеть.
    final catalog = FakeCatalogRepository(
      remote: [remoteDeck('fixture-good', version: 2)],
    )..downloadError = const NetworkError('нет сети');
    final router = await pumpDuelApp(
      tester,
      initial: '/duels/join',
      repo: repo,
      catalog: catalog,
    );
    await _enterAndJoin(tester, 'K7Q2MX');
    expect(router.state.uri.path, '/duels/duel-1');
    // Экран дуэли предлагает скачать колоду.
    expect(_key('duel-deck-missing'), findsOneWidget);
  });

  testWidgets('во время входа кнопка заблокирована', (tester) async {
    final repo = FakeDuelRepository()..joinGate = Completer<void>();
    await pumpDuelApp(tester, initial: '/duels/join', repo: repo);
    await tester.enterText(_key('duel-code-field'), 'K7Q2MX');
    await tester.tap(_key('duel-join-submit'));
    await tester.pump();
    expect(find.text('Входим…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('duel-join-submit')).onPressed,
      isNull,
    );
    repo.joinGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.joined, hasLength(1));
  });
}
