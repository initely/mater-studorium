import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/data/sync_providers.dart';
import 'package:mater_studorium/core/sync/domain/sync_store.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/features/auth/data/account_providers.dart';
import 'package:mater_studorium/features/auth/data/auth_providers.dart';
import 'package:mater_studorium/features/auth/domain/account_intent.dart';
import 'package:mater_studorium/features/auth/domain/auth_repository.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';
import 'package:mater_studorium/features/auth/presentation/auth_session_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_account.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSyncStore extends Mock implements SyncStore {}

void main() {
  late MockAuthRepository repo;
  late MockSyncStore store;
  late MemoryIntentStore intents;

  List<Override> overrides() => [
    authRepositoryProvider.overrideWithValue(repo),
    syncStoreProvider.overrideWithValue(store),
    accountIntentStoreProvider.overrideWithValue(intents),
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 12, 10)),
  ];

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repo = MockAuthRepository();
    store = MockSyncStore();
    intents = MemoryIntentStore();
    when(() => store.lastOwner()).thenAnswer((_) async => null);
    when(() => repo.userChanges()).thenAnswer((_) => const Stream.empty());
  });

  // testWidgets даёт фейковые часы: tester.pump(d) двигает Timer без реального ожидания.
  testWidgets('успешный вход: signingIn, затем signedIn', (tester) async {
    when(() => repo.ensureSignedIn()).thenAnswer((_) async {});
    final container = makeContainer();

    expect(container.read(authSessionProvider), AuthSessionStatus.signingIn);
    await tester.pump();

    expect(container.read(authSessionProvider), AuthSessionStatus.signedIn);
    verify(() => repo.ensureSignedIn()).called(1);
  });

  testWidgets('без сети: ошибки не наружу, повтор по таймеру, затем signedIn', (
    tester,
  ) async {
    var calls = 0;
    when(() => repo.ensureSignedIn()).thenAnswer((_) async {
      calls++;
      if (calls < 3) throw const NetworkError('offline');
    });
    final container = makeContainer();

    container.read(authSessionProvider);
    await tester.pump();
    expect(calls, 1);
    expect(container.read(authSessionProvider), AuthSessionStatus.signingIn);

    await tester.pump(authRetryDelays[0]);
    expect(calls, 2);
    expect(container.read(authSessionProvider), AuthSessionStatus.signingIn);

    await tester.pump(authRetryDelays[1]);
    expect(calls, 3);
    expect(container.read(authSessionProvider), AuthSessionStatus.signedIn);

    // После успеха новых попыток нет.
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 3);
  });

  testWidgets('повторы продолжаются с последней паузой, пока сети нет', (
    tester,
  ) async {
    var calls = 0;
    when(() => repo.ensureSignedIn()).thenAnswer((_) async {
      calls++;
      throw const NetworkError('offline');
    });
    final container = makeContainer();
    container.read(authSessionProvider);
    await tester.pump();

    for (var i = 0; i < authRetryDelays.length + 2; i++) {
      await tester.pump(authRetryDelays.last);
    }

    expect(calls, greaterThan(authRetryDelays.length));
    expect(container.read(authSessionProvider), AuthSessionStatus.signingIn);

    // Иначе останется ожидающий Timer, и testWidgets упадёт.
    container.dispose();
  });

  testWidgets('отказ сервера: failed, без повторов', (tester) async {
    var calls = 0;
    when(() => repo.ensureSignedIn()).thenAnswer((_) async {
      calls++;
      throw const AuthError('disabled');
    });
    final container = makeContainer();
    container.read(authSessionProvider);
    await tester.pump();

    await tester.pump(const Duration(minutes: 5));

    expect(calls, 1);
    expect(container.read(authSessionProvider), AuthSessionStatus.failed);
  });

  testWidgets('dispose отменяет ожидающий повтор', (tester) async {
    var calls = 0;
    when(() => repo.ensureSignedIn()).thenAnswer((_) async {
      calls++;
      throw const NetworkError('offline');
    });
    final container = ProviderContainer(overrides: overrides());
    container.read(authSessionProvider);
    await tester.pump();
    expect(calls, 1);

    container.dispose();
    await tester.pump(const Duration(minutes: 5));

    expect(calls, 1);
  });

  group('выход после входа (ревью T04)', () {
    late StreamController<AuthUser?> changes;
    const a = AuthUser(id: 'a', isAnonymous: true);

    setUp(() {
      changes = StreamController<AuthUser?>.broadcast();
      addTearDown(changes.close);
      when(() => repo.userChanges()).thenAnswer((_) => changes.stream);
    });

    testWidgets('сессия пропала (signedOut): снова анонимный вход', (
      tester,
    ) async {
      var calls = 0;
      when(() => repo.ensureSignedIn()).thenAnswer((_) async => calls++);
      final container = makeContainer();
      container.read(authSessionProvider);
      await tester.pump();
      expect(container.read(authSessionProvider), AuthSessionStatus.signedIn);
      expect(calls, 1);

      changes.add(a); // обновление токена и т. п. — не повод входить
      await tester.pump();
      expect(calls, 1);

      changes.add(null); // gotrue: refresh token отозван
      await tester.pump();
      expect(calls, 2);
      expect(container.read(authSessionProvider), AuthSessionStatus.signedIn);
    });

    testWidgets('после выхода без сети: повторы по таймеру, как при старте', (
      tester,
    ) async {
      var calls = 0;
      var online = true;
      when(() => repo.ensureSignedIn()).thenAnswer((_) async {
        calls++;
        if (!online) throw const NetworkError('offline');
      });
      final container = makeContainer();
      container.read(authSessionProvider);
      await tester.pump();
      expect(calls, 1);

      online = false;
      changes.add(null);
      await tester.pump();
      expect(calls, 2);
      expect(container.read(authSessionProvider), AuthSessionStatus.signingIn);

      online = true;
      await tester.pump(authRetryDelays[0]);
      expect(calls, 3);
      expect(container.read(authSessionProvider), AuthSessionStatus.signedIn);
    });

    testWidgets('null до первого входа (initialSession) не запускает лишний '
        'вход', (tester) async {
      var calls = 0;
      final gate = Completer<void>();
      when(() => repo.ensureSignedIn()).thenAnswer((_) async {
        calls++;
        await gate.future;
      });
      final container = makeContainer();
      container.read(authSessionProvider);
      await tester.pump();
      changes.add(null);
      await tester.pump();
      expect(calls, 1);
      gate.complete();
      await tester.pump();
      expect(container.read(authSessionProvider), AuthSessionStatus.signedIn);
    });
  });

  group('метка повторного входа relogin (ревью T21, B2)', () {
    const owner = AuthUser(id: 'old-anon', isAnonymous: true);

    testWidgets('нет сессии и на устройстве есть анонимный владелец: перед '
        'входом пишется relogin', (tester) async {
      when(() => store.lastOwner()).thenAnswer((_) async => owner);
      AccountIntentKind? kindAtSignIn;
      when(() => repo.ensureSignedIn()).thenAnswer((_) async {
        kindAtSignIn = intents.intent?.kind;
      });
      final container = makeContainer();

      container.read(authSessionProvider);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        kindAtSignIn,
        AccountIntentKind.relogin,
        reason: 'запись должна быть до входа',
      );
      expect(intents.intent?.fromUserId, 'old-anon');
      expect(container.read(authSessionProvider), AuthSessionStatus.signedIn);
    });

    testWidgets('сессия есть: relogin не пишется (ожидающий merge цел)', (
      tester,
    ) async {
      when(() => store.lastOwner()).thenAnswer((_) async => owner);
      when(() => repo.currentUser).thenReturn(owner);
      final pending = AccountIntent(
        kind: AccountIntentKind.merge,
        fromUserId: 'old-anon',
        createdAt: DateTime.utc(2026, 10, 12, 10),
      );
      intents.intent = pending;
      when(() => repo.ensureSignedIn()).thenAnswer((_) async {});
      final container = makeContainer();

      container.read(authSessionProvider);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(intents.intent, pending);
    });

    for (final (name, lastOwner) in <(String, AuthUser?)>[
      ('первый запуск (владельца нет)', null),
      (
        'прежний владелец не анонимный',
        const AuthUser(id: 'g', isAnonymous: false),
      ),
    ]) {
      testWidgets('$name: relogin не пишется', (tester) async {
        when(() => store.lastOwner()).thenAnswer((_) async => lastOwner);
        when(() => repo.ensureSignedIn()).thenAnswer((_) async {});
        final container = makeContainer();

        container.read(authSessionProvider);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(intents.intent, isNull);
      });
    }

    testWidgets('ошибка записи метки не мешает входу', (tester) async {
      when(() => store.lastOwner()).thenThrow(StateError('db'));
      when(() => repo.ensureSignedIn()).thenAnswer((_) async {});
      final container = makeContainer();

      container.read(authSessionProvider);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(container.read(authSessionProvider), AuthSessionStatus.signedIn);
    });
  });
}
