// AccountNotifier: состояния привязки Google (T21, ADR-34).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mater_studorium/core/sync/data/sync_providers.dart';
import 'package:mater_studorium/core/sync/domain/account_switch_handler.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/features/auth/data/account_providers.dart';
import 'package:mater_studorium/features/auth/data/auth_providers.dart';
import 'package:mater_studorium/features/auth/domain/account_failure.dart';
import 'package:mater_studorium/features/auth/domain/account_intent.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';
import 'package:mater_studorium/features/auth/presentation/account_notifier.dart';
import 'package:mater_studorium/features/auth/presentation/account_return_listener.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_account.dart';

class MockSwitchHandler extends Mock implements AccountSwitchHandler {}

void main() {
  setUpAll(
    () => registerFallbackValue(const AuthUser(id: 'x', isAnonymous: false)),
  );

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

    test('аноним -> Google с другим id: само по себе сообщения нет, оно '
        'зависит от итога переноса (S1)', () async {
      final c = container();

      auth.emitUser(const AuthUser(id: 'other', isAnonymous: false));
      await settle();

      expect(c.read(accountProvider).notice, isNull);
      expect(c.read(accountProvider).user!.id, 'other');
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

  group('итог переноса прогресса (ревью T21, S1)', () {
    const google = AuthUser(
      id: 'g-1',
      isAnonymous: false,
      email: 'g@example.com',
    );

    Future<ProviderContainer> signedInAsGoogle() async {
      final c = container();
      auth.emitUser(google);
      await settle();
      return c;
    }

    void publish(ProviderContainer c, AccountSwitchOutcome outcome) => c
        .read(accountSwitchResultProvider.notifier)
        .publish(
          AccountSwitchResult(outcome, fromUserId: 'anon-1', user: google),
        );

    ProviderContainer withHandler(MockSwitchHandler handler) {
      final c = ProviderContainer(
        overrides: [
          ...overrides(),
          accountSwitchHandlerProvider.overrideWithValue(handler),
        ],
      );
      addTearDown(c.dispose);
      c.read(accountProvider);
      return c;
    }

    test('adopted: «объединён»', () async {
      final c = await signedInAsGoogle();

      publish(c, AccountSwitchOutcome.adopted);
      await settle();

      expect(c.read(accountProvider).notice, AccountNotice.signedInExisting);
      expect(c.read(accountProvider).strandedFromUserId, isNull);
    });

    test('notConfirmed (подтверждение устарело): честное сообщение и повтор, '
        'НЕ «объединён»', () async {
      final c = await signedInAsGoogle();

      publish(c, AccountSwitchOutcome.notConfirmed);
      await settle();

      final s = c.read(accountProvider);
      expect(s.notice, AccountNotice.mergeNotConfirmed);
      expect(s.notice, isNot(AccountNotice.signedInExisting));
      expect(s.strandedFromUserId, 'anon-1');
    });

    test('failed: ошибка и повтор', () async {
      final c = await signedInAsGoogle();

      publish(c, AccountSwitchOutcome.failed);
      await settle();

      expect(c.read(accountProvider).notice, AccountNotice.mergeFailed);
      expect(c.read(accountProvider).strandedFromUserId, 'anon-1');
    });

    test('none и вход анонимного ничего не показывают', () async {
      final c = container();

      c
          .read(accountSwitchResultProvider.notifier)
          .publish(
            const AccountSwitchResult(
              AccountSwitchOutcome.adopted,
              fromUserId: 'anon-1',
              user: AuthUser(id: 'anon-2', isAnonymous: true),
            ),
          );
      publish(c, AccountSwitchOutcome.none);
      await settle();

      expect(c.read(accountProvider).notice, isNull);
    });

    test(
      'итог пришёл до создания уведомителя: применяется при создании',
      () async {
        final c = ProviderContainer(overrides: overrides());
        addTearDown(c.dispose);
        auth.emitUser(google);
        publish(c, AccountSwitchOutcome.notConfirmed);

        c.read(accountProvider);
        await settle();

        expect(c.read(accountProvider).notice, AccountNotice.mergeNotConfirmed);
      },
    );

    test('повтор по кнопке: сбой -> mergeFailed и повтор остаётся, успех -> '
        '«объединён»', () async {
      final handler = MockSwitchHandler();
      final c = withHandler(handler);
      auth.emitUser(google);
      await settle();
      publish(c, AccountSwitchOutcome.notConfirmed);
      await settle();
      final n = c.read(accountProvider.notifier);

      when(() => handler.adoptConfirmed(fromUserId: 'anon-1', user: google))
          .thenAnswer(
            (_) async => const AccountSwitchResult(
              AccountSwitchOutcome.failed,
              fromUserId: 'anon-1',
              user: google,
            ),
          );
      await n.retryMerge();
      expect(c.read(accountProvider).notice, AccountNotice.mergeFailed);
      expect(c.read(accountProvider).strandedFromUserId, 'anon-1');

      when(() => handler.adoptConfirmed(fromUserId: 'anon-1', user: google))
          .thenAnswer(
            (_) async => const AccountSwitchResult(
              AccountSwitchOutcome.adopted,
              fromUserId: 'anon-1',
              user: google,
            ),
          );
      await n.retryMerge();
      expect(c.read(accountProvider).notice, AccountNotice.signedInExisting);
      expect(c.read(accountProvider).strandedFromUserId, isNull);
    });

    test('retryMerge без оставшегося прогресса ничего не делает', () async {
      final handler = MockSwitchHandler();
      final c = withHandler(handler);

      await c.read(accountProvider.notifier).retryMerge();

      verifyNever(
        () => handler.adoptConfirmed(
          fromUserId: any(named: 'fromUserId'),
          user: any(named: 'user'),
        ),
      );
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
