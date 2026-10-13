import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';

import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_duel_repository.dart';
import 'duel_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

FakeDuelQuestionSource _source() => FakeDuelQuestionSource(
  snapshots: {
    'alpha': snapshotOf(12),
    'beta': snapshotOf(8, version: 3),
    'small': snapshotOf(3),
  },
);

Future<void> _selectAndCreate(WidgetTester tester, String deck) async {
  await tester.tap(_key('duel-deck-$deck'));
  await tester.pump();
  await tester.tap(_key('duel-create-submit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('нет скачанных колод: подсказка и переход к колодам', (
    tester,
  ) async {
    final router = await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: FakeDuelRepository(),
    );
    expect(
      find.text('Сначала скачай колоду: вопросы для дуэли берутся из неё.'),
      findsOneWidget,
    );
    await tester.tap(_key('duel-to-decks'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/decks');
  });

  testWidgets('создать нельзя, пока колода не выбрана; тап-цели не меньше 48', (
    tester,
  ) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: FakeDuelRepository(),
      source: _source(),
      catalog: FakeCatalogRepository(
        local: [localDeck('alpha'), localDeck('beta')],
      ),
    );
    expect(
      tester.widget<FilledButton>(_key('duel-create-submit')).onPressed,
      isNull,
    );
    expectTapTarget(tester, const Key('duel-create-submit'));
    expectTapTarget(tester, const Key('duel-deck-alpha'));
    await tester.tap(_key('duel-deck-beta'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(_key('duel-create-submit')).onPressed,
      isNotNull,
    );
  });

  testWidgets('одна колода выбрана сразу', (tester) async {
    await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: FakeDuelRepository(),
      source: _source(),
      catalog: FakeCatalogRepository(local: [localDeck('alpha')]),
    );
    expect(
      tester.widget<FilledButton>(_key('duel-create-submit')).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'создание: 5 разных вопросов выбранной колоды уходят на сервер, показан код',
    (tester) async {
      final repo = FakeDuelRepository();
      await pumpDuelApp(
        tester,
        initial: '/duels/new',
        repo: repo,
        source: _source(),
        catalog: FakeCatalogRepository(
          local: [localDeck('alpha'), localDeck('beta')],
        ),
      );
      await _selectAndCreate(tester, 'beta');

      final call = repo.created.single;
      expect(call.duelId, 'duel-uuid-1');
      expect(call.deckId, 'beta');
      expect(call.deckVersion, 3);
      expect(call.questionIds, hasLength(5));
      expect(call.questionIds.toSet(), hasLength(5));
      expect(
        call.questionIds.every((q) => RegExp(r'^q\.([1-8])$').hasMatch(q)),
        isTrue,
        reason: '${call.questionIds}',
      );
      expect(_key('duel-created'), findsOneWidget);
      expect(find.text('K7Q 2MX'), findsOneWidget);
      expectTapTarget(tester, const Key('duel-copy-code'));
      expectTapTarget(tester, const Key('duel-copy-invite'));
      expectTapTarget(tester, const Key('duel-open'));
    },
  );

  testWidgets('код озвучивается по знакам', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: FakeDuelRepository(),
      source: _source(),
      catalog: FakeCatalogRepository(local: [localDeck('alpha')]),
    );
    await tester.tap(_key('duel-create-submit'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Код: K 7 Q 2 M X')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('копирование кода и приглашения', (tester) async {
    final copied = captureClipboard(tester);
    await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: FakeDuelRepository(),
      source: _source(),
      catalog: FakeCatalogRepository(local: [localDeck('alpha')]),
    );
    await tester.tap(_key('duel-create-submit'));
    await tester.pumpAndSettle();

    await tester.tap(_key('duel-copy-code'));
    await tester.pump();
    expect(copied, ['K7Q2MX']);
    expect(find.text('Скопировано'), findsOneWidget);

    await tester.tap(_key('duel-copy-invite'));
    await tester.pump();
    expect(copied.last, 'Сыграем дуэль в Mater Studorium? Код: K7Q2MX');
  });

  testWidgets('«К дуэли» открывает экран состояния созданной дуэли', (
    tester,
  ) async {
    final repo = FakeDuelRepository()
      ..getResult = duelFixture(id: 'duel-uuid-1');
    final router = await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: repo,
      source: _source(),
      catalog: FakeCatalogRepository(local: [localDeck('alpha')]),
    );
    await tester.tap(_key('duel-create-submit'));
    await tester.pumpAndSettle();
    await tester.tap(_key('duel-open'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/duels/duel-uuid-1');
    expect(find.text('Твой ход'), findsOneWidget);
  });

  testWidgets(
    'в колоде меньше пяти вопросов: понятная ошибка, сервер не вызван',
    (tester) async {
      final repo = FakeDuelRepository();
      await pumpDuelApp(
        tester,
        initial: '/duels/new',
        repo: repo,
        source: _source(),
        catalog: FakeCatalogRepository(
          local: [localDeck('small'), localDeck('alpha')],
        ),
      );
      await _selectAndCreate(tester, 'small');
      expect(
        find.text(
          'В этой колоде мало подходящих вопросов: 3, нужно 5. Выбери другую колоду.',
        ),
        findsOneWidget,
      );
      expect(repo.created, isEmpty);
    },
  );

  testWidgets('нет колоды в локальной базе: ошибка про колоду', (tester) async {
    final repo = FakeDuelRepository();
    await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: repo,
      source: FakeDuelQuestionSource(), // снимков нет
      catalog: FakeCatalogRepository(local: [localDeck('alpha')]),
    );
    await tester.tap(_key('duel-create-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Эта колода недоступна для дуэли.'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  group('ошибки сервера', () {
    final cases = <(String, AppError, String)>[
      (
        'нет сети',
        const NetworkError('x'),
        'Нужна сеть. Проверь подключение и повтори.',
      ),
      (
        'лимит активных',
        const DuelLimitError(DuelLimitKind.activeDuels),
        'Слишком много активных дуэлей. Дождись окончания прежних.',
      ),
      (
        'лимит в сутки',
        const DuelLimitError(DuelLimitKind.dailyCreate),
        'Сегодня создано слишком много дуэлей. Попробуй завтра.',
      ),
      (
        'нет входа',
        const AuthError('нет сессии'),
        'Нет входа в аккаунт. Перезапусти приложение.',
      ),
      (
        'колода отклонена',
        const DeckNotFoundError('alpha'),
        'Эта колода недоступна для дуэли.',
      ),
      (
        'прочее',
        const UnexpectedError('x'),
        'Не удалось выполнить действие. Попробуй ещё раз.',
      ),
    ];
    for (final (name, error, text) in cases) {
      testWidgets(name, (tester) async {
        final repo = FakeDuelRepository()..createError = error;
        await pumpDuelApp(
          tester,
          initial: '/duels/new',
          repo: repo,
          source: _source(),
          catalog: FakeCatalogRepository(local: [localDeck('alpha')]),
        );
        await tester.tap(_key('duel-create-submit'));
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
        expect(_key('duel-created'), findsNothing);
        // Кнопка снова доступна.
        expect(
          tester.widget<FilledButton>(_key('duel-create-submit')).onPressed,
          isNotNull,
        );
      });
    }
  });

  testWidgets(
    'повтор после сбоя сети отправляет тот же id дуэли (идемпотентность)',
    (tester) async {
      final repo = FakeDuelRepository()..createError = const NetworkError('x');
      await pumpDuelApp(
        tester,
        initial: '/duels/new',
        repo: repo,
        source: _source(),
        catalog: FakeCatalogRepository(local: [localDeck('alpha')]),
      );
      await tester.tap(_key('duel-create-submit'));
      await tester.pumpAndSettle();
      repo.createError = null;
      await tester.tap(_key('duel-create-submit'));
      await tester.pumpAndSettle();
      expect(repo.created, hasLength(2));
      expect(repo.created[0].duelId, repo.created[1].duelId);
      expect(_key('duel-created'), findsOneWidget);
    },
  );

  testWidgets('после сбоя для одной колоды другая получает новый id дуэли', (
    tester,
  ) async {
    final repo = FakeDuelRepository()..createError = const NetworkError('x');
    await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: repo,
      source: _source(),
      catalog: FakeCatalogRepository(
        local: [localDeck('alpha'), localDeck('beta')],
      ),
    );
    await _selectAndCreate(tester, 'alpha');
    repo.createError = null;
    await _selectAndCreate(tester, 'beta');
    expect(repo.created, hasLength(2));
    expect(repo.created[0].deckId, 'alpha');
    expect(repo.created[1].deckId, 'beta');
    expect(repo.created[1].duelId, isNot(repo.created[0].duelId));
  });

  testWidgets('двойной тап не создаёт две дуэли, кнопка блокируется', (
    tester,
  ) async {
    final repo = FakeDuelRepository()..createGate = Completer<void>();
    await pumpDuelApp(
      tester,
      initial: '/duels/new',
      repo: repo,
      source: _source(),
      catalog: FakeCatalogRepository(local: [localDeck('alpha')]),
    );
    await tester.tap(_key('duel-create-submit'));
    await tester.pump();
    expect(find.text('Создаём…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('duel-create-submit')).onPressed,
      isNull,
    );
    repo.createGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.created, hasLength(1));
    expect(repo.created.single.questionIds, hasLength(5));
    // Статус по умолчанию у фикстуры — open.
    expect(DuelStatus.open, isNotNull);
  });
}
