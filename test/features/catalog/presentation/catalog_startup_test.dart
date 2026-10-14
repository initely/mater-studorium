// Запуск и каталог (POLISH п. 1, 3): «нужна сеть» не показывается, пока
// анонимный вход не завершился; сбой инициализации Supabase даёт обычную
// ошибку сети с «Повторить» и повторной попыткой инициализации, а не красный
// экран.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/supabase/supabase_init.dart';
import 'package:mater_studorium/features/auth/presentation/auth_session_notifier.dart';
import 'package:mater_studorium/features/catalog/presentation/catalog_notifier.dart';
import 'package:mater_studorium/features/catalog/presentation/decks_screen.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/fake_supabase.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/unmount_app.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DecksScreen)));

void main() {
  group('ожидание анонимного входа (п. 1)', () {
    late SessionGatedRemote remote;

    setUp(() => remote = SessionGatedRemote(SampleRemote()));

    Future<void> pumpDecks(WidgetTester tester) async {
      await tester.pumpApp(
        const DecksScreen(),
        overrides: [
          ...appOverrides(memoryDb()),
          supabaseStatusProvider.overrideWith(ReadyStatus.new),
          authSessionProvider.overrideWith(FakeAuthSession.new),
          remoteByStatus(remote),
        ],
      );
      await tester.pump();
    }

    testWidgets('пока вход идёт, запроса и ошибки нет; после входа каталог '
        'загружается сам', (tester) async {
      await pumpDecks(tester);
      await tester.pump(const Duration(seconds: 5));

      expect(remote.fetches, 0, reason: 'без сессии каталог не запрашиваем');
      expect(find.byKey(const Key('decks-list-error')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      remote.signedIn = true;
      (_container(tester).read(authSessionProvider.notifier) as FakeAuthSession)
          .set(AuthSessionStatus.signedIn);
      await tester.pumpAndSettle();

      expect(remote.fetches, 1);
      expect(find.byKey(const Key('decks-list-error')), findsNothing);
      expect(find.byKey(const Key('deck-action-sample')), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('вход не завершился за catalogSessionWait: честная ошибка сети '
        'с «Повторить»', (tester) async {
      await pumpDecks(tester);
      await tester.pump(catalogSessionWait + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(remote.fetches, 1);
      expect(find.byKey(const Key('decks-list-error')), findsOneWidget);
      expect(find.textContaining('нужна сеть'), findsOneWidget);
      expect(find.byKey(const Key('decks-retry')), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets(
      'сервер отказал во входе (failed): не ждём, запрашиваем сразу',
      (tester) async {
        await pumpDecks(tester);
        (_container(tester).read(
          authSessionProvider.notifier,
        ) as FakeAuthSession).set(AuthSessionStatus.failed);
        await tester.pumpAndSettle();

        expect(remote.fetches, 1);
        expect(find.byKey(const Key('decks-list-error')), findsOneWidget);
        await tester.unmountApp();
      },
    );

    testWidgets('вход уже выполнен: запрос сразу, без ожидания', (
      tester,
    ) async {
      remote.signedIn = true;
      await tester.pumpApp(
        const DecksScreen(),
        overrides: [
          ...appOverrides(memoryDb()),
          supabaseStatusProvider.overrideWith(ReadyStatus.new),
          authSessionProvider.overrideWith(
            () => FakeAuthSession(AuthSessionStatus.signedIn),
          ),
          remoteByStatus(remote),
        ],
      );
      await tester.pumpAndSettle();

      expect(remote.fetches, 1);
      expect(find.byKey(const Key('deck-action-sample')), findsOneWidget);
      await tester.unmountApp();
    });
  });

  group('сбой инициализации Supabase (п. 3)', () {
    testWidgets('экран колод: ошибка сети и «Повторить», без красного экрана; '
        'повтор пробует инициализацию заново и загружает каталог', (
      tester,
    ) async {
      var attempts = 0;
      var works = false;
      await tester.pumpApp(
        const DecksScreen(),
        overrides: [
          ...appOverrides(memoryDb()),
          ...fakeBackend(
            onInit: () async {
              attempts++;
              if (!works) {
                throw const FormatException(
                  'Scheme not starting with alphabetic character',
                  ':',
                  0,
                );
              }
            },
          ),
          remoteByStatus(SampleRemote()),
          authSessionProvider.overrideWith(
            () => FakeAuthSession(AuthSessionStatus.signedIn),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Первая попытка (при открытии экрана) не удалась: обычная ошибка сети.
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('decks-list-error')), findsOneWidget);
      expect(find.textContaining('нужна сеть'), findsOneWidget);
      expect(attempts, 1);

      // «Повторить» при прежнем сбое: инициализация снова пробуется и снова
      // не удаётся, экран остаётся целым.
      await tester.tap(find.byKey(const Key('decks-retry')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('decks-list-error')), findsOneWidget);

      // Сбой прошёл: повтор инициализирует Supabase и загружает каталог.
      works = true;
      await tester.tap(find.byKey(const Key('decks-retry')));
      await tester.pumpAndSettle();
      expect(attempts, 3);
      expect(find.byKey(const Key('decks-list-error')), findsNothing);
      expect(find.byKey(const Key('deck-action-sample')), findsOneWidget);
      expect(
        _container(tester).read(supabaseStatusProvider),
        SupabaseStatus.ready,
      );
      await tester.unmountApp();
    });
  });
}
