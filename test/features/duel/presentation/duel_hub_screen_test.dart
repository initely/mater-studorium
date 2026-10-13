import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/isolate_name.dart';

import '../../../helpers/fake_duel_repository.dart';
import 'duel_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

void main() {
  testWidgets('пусто: подсказка и две кнопки с нужными тап-целями', (
    tester,
  ) async {
    await pumpDuelApp(tester, initial: '/duels', repo: FakeDuelRepository());
    expect(_key('duels-empty'), findsOneWidget);
    expectTapTarget(tester, const Key('duels-create'));
    expectTapTarget(tester, const Key('duels-join'));
    expectTapTarget(tester, const Key('duel-name-save'));
  });

  testWidgets('кнопки ведут на создание и вход', (tester) async {
    final router = await pumpDuelApp(
      tester,
      initial: '/duels',
      repo: FakeDuelRepository(),
    );
    await tester.tap(_key('duels-create'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/duels/new');
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(_key('duels-join'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/duels/join');
  });

  testWidgets('список: с кем, статус и срок; тап открывает дуэль', (
    tester,
  ) async {
    final repo = FakeDuelRepository(
      mineResult: [
        duelFixture(id: 'a'),
        duelFixture(
          id: 'b',
          isCreator: false,
          otherJoined: true,
          otherName: 'Алиса',
          status: DuelStatus.active,
          code: null,
          myDoneAt: duelNow,
        ),
        duelFixture(id: 'c', otherJoined: true, status: DuelStatus.finished),
        duelFixture(
          id: 'd',
          createdAt: duelNow.subtract(const Duration(days: 4)),
          expiresAt: duelNow.subtract(const Duration(days: 1)),
        ),
      ],
    )..getResult = duelFixture(id: 'b');
    final router = await pumpDuelApp(tester, initial: '/duels', repo: repo);
    expect(find.text('Дуэль, ждём соперника'), findsNWidgets(2));
    expect(find.text('Твой ход · осталось 3 д'), findsOneWidget);
    expect(find.text('Дуэль с ${isolateName('Алиса')}'), findsOneWidget);
    expect(
      find.text('Ждём ${isolateName('Алиса')} · осталось 3 д'),
      findsOneWidget,
    );
    expect(find.text('Соперник без имени'), findsOneWidget);
    expect(find.text('Результат готов'), findsOneWidget);
    // Просроченная по часам клиента: без срока.
    expect(find.text('Дуэль истекла'), findsOneWidget);

    await tester.tap(_key('duel-b'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/duels/b');
  });

  testWidgets(
    'длинное имя соперника: заголовок в одну строку с многоточием, имя в изоляции',
    (tester) async {
      final name = 'Я' * 64;
      final repo = FakeDuelRepository(
        mineResult: [
          duelFixture(
            id: 'long',
            otherJoined: true,
            otherName: name,
            status: DuelStatus.active,
          ),
        ],
      );
      await pumpDuelApp(tester, initial: '/duels', repo: repo);
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('duel-long')),
          matching: find.text('Дуэль с ${isolateName(name)}'),
        ),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ошибка загрузки списка: сообщение и повтор', (tester) async {
    final repo = FakeDuelRepository()..mineError = const NetworkError('x');
    await pumpDuelApp(tester, initial: '/duels', repo: repo);
    expect(_key('duels-error'), findsOneWidget);
    repo
      ..mineError = null
      ..mineResult = [duelFixture(id: 'a')];
    await tester.tap(_key('duels-retry'));
    await tester.pumpAndSettle();
    expect(_key('duels-error'), findsNothing);
    expect(_key('duel-a'), findsOneWidget);
  });

  group('имя для соперника', () {
    testWidgets('показывается сохранённое имя', (tester) async {
      await pumpDuelApp(
        tester,
        initial: '/duels',
        repo: FakeDuelRepository(displayName: 'Саша'),
      );
      expect(
        tester.widget<TextField>(_key('duel-name-field')).controller!.text,
        'Саша',
      );
    });

    testWidgets('сохраняется очищенным от bidi и пробелов', (tester) async {
      final repo = FakeDuelRepository();
      await pumpDuelApp(tester, initial: '/duels', repo: repo);
      await tester.enterText(
        _key('duel-name-field'),
        '  Са${String.fromCharCode(0x202E)}ша  ',
      );
      await tester.tap(_key('duel-name-save'));
      await tester.pumpAndSettle();
      expect(repo.nameWrites, ['Саша']);
      expect(find.text('Имя сохранено'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('duel-name-field')).controller!.text,
        'Саша',
      );
    });

    testWidgets('пустой ввод убирает имя', (tester) async {
      final repo = FakeDuelRepository(displayName: 'Саша');
      await pumpDuelApp(tester, initial: '/duels', repo: repo);
      await tester.enterText(_key('duel-name-field'), '   ');
      await tester.tap(_key('duel-name-save'));
      await tester.pumpAndSettle();
      expect(repo.nameWrites, [null]);
    });

    testWidgets('ошибка сохранения: сообщение, введённое остаётся', (
      tester,
    ) async {
      final repo = FakeDuelRepository()
        ..setNameError = const RequestRejectedError('x', code: '23514');
      await pumpDuelApp(tester, initial: '/duels', repo: repo);
      await tester.enterText(_key('duel-name-field'), 'Саша');
      await tester.tap(_key('duel-name-save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось сохранить имя. Проверь сеть и попробуй ещё раз.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(_key('duel-name-field')).controller!.text,
        'Саша',
      );
    });
  });
}
