import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/auth/data/auth_providers.dart';
import 'package:mater_studorium/features/auth/domain/auth_repository.dart';
import 'package:mater_studorium/features/auth/presentation/auth_session_notifier.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => repo = MockAuthRepository());

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
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    container.read(authSessionProvider);
    await tester.pump();
    expect(calls, 1);

    container.dispose();
    await tester.pump(const Duration(minutes: 5));

    expect(calls, 1);
  });
}
