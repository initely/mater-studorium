// AccountNotifier: состояния привязки Google (T21, ADR-34).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/features/auth/data/account_providers.dart';
import 'package:mater_studorium/features/auth/data/auth_providers.dart';
import 'package:mater_studorium/features/auth/domain/account_failure.dart';
import 'package:mater_studorium/features/auth/domain/account_intent.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';
import 'package:mater_studorium/features/auth/presentation/account_notifier.dart';
import 'package:mater_studorium/features/auth/presentation/account_return_listener.dart';

import '../../../helpers/fake_account.dart';

void main() {
  const anon = AuthUser(id: 'anon-1', isAnonymous: true);
  final t0 = DateTime.utc(2026, 10, 12, 10);

  late FakeAuthRepository auth;
  late MemoryIntentStore intents;

  setUp(() {
    auth = FakeAuthRepository(anon);
    intents = MemoryIntentStore();
    addTearDown(auth.dispose);
  });

  List<Override> overrides({bool configured = true}) => [
    authRepositoryProvider.overrideWithValue(auth),
    accountIntentStoreProvider.overrideWithValue(intents),
    backendConfiguredProvider.overrideWithValue(configured),
    clockProvider.overrideWithValue(() => t0),
  ];

  ProviderContainer container({bool configured = true}) {
    final c = ProviderContainer(overrides: overrides(configured: configured));
    addTearDown(c.dispose);
    c.read(accountProvider);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('без бэкенда: недоступно, действия ничего не делают', () async {
    final c = container(configured: false);

    expect(c.read(accountProvider).available, isFalse);
    await c.read(accountProvider.notifier).linkGoogle();
    await c.read(accountProvider.notifier).confirmMerge();

    expect(auth.linkCalls + auth.signInCalls, 0);
    expect(c.read(accountProvider).needsAttention, isFalse);
  });

  test('начальное состояние: текущий аноним, без сообщений', () {
    final s = container().read(accountProvider);

    expect(s.user, anon);
    expect(s.phase, AccountPhase.idle);
    expect(s.notice, isNull);
    expect(s.needsAttention, isFalse);
  });

  test('двойной тап: браузер открывается один раз', () async {
    final c = container();
    final gate = auth.hold();
    final n = c.read(accountProvider.notifier);

    final first = n.linkGoogle();
    final second = n.linkGoogle();
    expect(c.read(accountProvider).phase, AccountPhase.working);
    gate.complete();
    await first;
    await second;

    expect(auth.linkCalls, 1);
    expect(c.read(accountProvider).phase, AccountPhase.idle);
  });

  group('смена пользователя', () {
    test('аноним -> Google с тем же id: linked', () async {
      final c = container();

      auth.emitUser(
        const AuthUser(
          id: 'anon-1',
          isAnonymous: false,
          email: 'a@example.com',
        ),
      );
      await settle();

      final s = c.read(accountProvider);
      expect(s.notice, AccountNotice.linked);
      expect(s.user!.email, 'a@example.com');
      expect(s.needsAttention, isTrue);
    });

    test('аноним -> Google с другим id: signedInExisting', () async {
      final c = container();

      auth.emitUser(const AuthUser(id: 'other', isAnonymous: false));
      await settle();

      expect(c.read(accountProvider).notice, AccountNotice.signedInExisting);
    });

    test(
      'аноним -> другой аноним (потерянная сессия): без сообщения',
      () async {
        final c = container();

        auth.emitUser(const AuthUser(id: 'anon-2', isAnonymous: true));
        await settle();

        expect(c.read(accountProvider).notice, isNull);
        expect(c.read(accountProvider).user!.id, 'anon-2');
      },
    );

    test('повтор того же пользователя и выход не меняют состояние', () async {
      final c = container();

      auth.emitUser(anon);
      auth.emitUser(null);
      await settle();

      expect(c.read(accountProvider).user, anon);
      expect(c.read(accountProvider).notice, isNull);
    });

    test('dismissNotice скрывает сообщение', () async {
      final c = container();
      auth.emitUser(const AuthUser(id: 'anon-1', isAnonymous: false));
      await settle();

      c.read(accountProvider.notifier).dismissNotice();

      expect(c.read(accountProvider).notice, isNull);
    });
  });

  group('конфликт', () {
    test('событие при свежем link: фаза conflict; decline возвращает idle '
        'и сбрасывает намерение', () async {
      final c = container();
      final n = c.read(accountProvider.notifier);
      await n.linkGoogle();

      auth.emitFailure(AccountFailureKind.identityAlreadyExists);
      await settle();
      expect(c.read(accountProvider).phase, AccountPhase.conflict);
      expect(c.read(accountProvider).needsAttention, isTrue);

      await n.declineMerge();
      expect(c.read(accountProvider).phase, AccountPhase.idle);
      expect(intents.intent, isNull);
      expect(auth.signInCalls, 0);
    });

    test(
      'confirmMerge из конфликта: merge записан, браузер для входа открыт',
      () async {
        final c = container();
        final n = c.read(accountProvider.notifier);
        await n.linkGoogle();
        auth.emitFailure(AccountFailureKind.identityAlreadyExists);
        await settle();

        await n.confirmMerge();

        expect(auth.signInCalls, 1);
        expect(intents.intent?.kind, AccountIntentKind.merge);
        expect(c.read(accountProvider).phase, AccountPhase.idle);
      },
    );
  });

  Future<GoRouter> pumpRouter(
    WidgetTester tester,
    ProviderContainer c, {
    String initial = '/',
  }) async {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: kSettingsRoute,
          builder: (_, _) => const Text('settings'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              AccountReturnListener(router: router, child: child!),
        ),
      ),
    );
    return router;
  }

  testWidgets('AccountReturnListener: итог пришёл на другом экране, '
      'открываются настройки', (tester) async {
    final c = container();
    final router = await pumpRouter(tester, c);
    expect(find.text('home'), findsOneWidget);

    auth.emitUser(const AuthUser(id: 'anon-1', isAnonymous: false));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('settings'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
  });

  testWidgets('AccountReturnListener: конфликт тоже открывает настройки', (
    tester,
  ) async {
    final c = container();
    await pumpRouter(tester, c);
    await c.read(accountProvider.notifier).linkGoogle();

    auth.emitFailure(AccountFailureKind.identityAlreadyExists);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('AccountReturnListener: уже на настройках, второй экран не '
      'открывается', (tester) async {
    final c = container();
    final router = await pumpRouter(tester, c, initial: kSettingsRoute);

    auth.emitUser(const AuthUser(id: 'anon-1', isAnonymous: false));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
  });

  testWidgets('AccountReturnListener: без причины ничего не открывает', (
    tester,
  ) async {
    final c = container();
    await pumpRouter(tester, c);

    auth.emitUser(const AuthUser(id: 'anon-2', isAnonymous: true));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
