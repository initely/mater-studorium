// Привязка Google: все ветки AccountLinkService (T21, ADR-34).

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/auth/domain/account_event.dart';
import 'package:mater_studorium/features/auth/domain/account_failure.dart';
import 'package:mater_studorium/features/auth/domain/account_intent.dart';
import 'package:mater_studorium/features/auth/domain/account_link_service.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';

import '../../../helpers/fake_account.dart';

void main() {
  const anon = AuthUser(id: 'anon-1', isAnonymous: true);
  const google = AuthUser(id: 'anon-1', isAnonymous: false);
  final t0 = DateTime.utc(2026, 10, 12, 10);
  var now = t0;

  late FakeAuthRepository auth;
  late MemoryIntentStore intents;
  late AccountLinkService service;

  setUp(() {
    now = t0;
    auth = FakeAuthRepository(anon);
    intents = MemoryIntentStore();
    service = AccountLinkService(
      auth: auth,
      intents: intents,
      clock: () => now,
    );
    addTearDown(auth.dispose);
  });

  AccountIntent intent(AccountIntentKind kind, {String from = 'anon-1'}) =>
      AccountIntent(kind: kind, fromUserId: from, createdAt: t0);

  Future<AccountEvent?> firstEvent(
    AccountFailureKind kind, {
    Duration wait = const Duration(milliseconds: 50),
  }) async {
    final events = <AccountEvent>[];
    final sub = service.events().listen(events.add);
    await Future<void>.delayed(Duration.zero);
    auth.emitFailure(kind);
    await Future<void>.delayed(wait);
    await sub.cancel();
    return events.isEmpty ? null : events.single;
  }

  group('startLink', () {
    test('пишет намерение link и открывает браузер', () async {
      expect(await service.startLink(), isNull);

      expect(auth.linkCalls, 1);
      expect(auth.signInCalls, 0);
      expect(intents.intent, intent(AccountIntentKind.link));
    });

    test('не из анонимного аккаунта: браузер не открывается', () async {
      auth.emitUser(google);
      expect(await service.startLink(), AccountEvent.failed);
      auth.emitUser(null);
      expect(await service.startLink(), AccountEvent.failed);

      expect(auth.linkCalls, 0);
      expect(intents.intent, isNull);
    });

    for (final (error, event) in <(AppError, AccountEvent)>[
      (const ProviderUnavailableError('off'), AccountEvent.unavailable),
      (const NetworkError('offline'), AccountEvent.network),
      (const AuthError('denied'), AccountEvent.failed),
      (const UnexpectedError('boom'), AccountEvent.failed),
    ]) {
      test('${error.runtimeType} -> $event, намерение сбрасывается', () async {
        auth.launchError = error;

        expect(await service.startLink(), event);
        expect(intents.intent, isNull);
      });
    }
  });

  group('events', () {
    test('identity_already_exists при свежем link: конфликт, намерение '
        'остаётся до решения', () async {
      intents.intent = intent(AccountIntentKind.link);

      expect(
        await firstEvent(AccountFailureKind.identityAlreadyExists),
        AccountEvent.conflict,
      );
      expect(intents.intent, intent(AccountIntentKind.link));
    });

    test('без намерения событие чужое: игнорируется', () async {
      for (final kind in AccountFailureKind.values) {
        expect(await firstEvent(kind), isNull, reason: '$kind');
      }
    });

    test('просроченное намерение (старше 15 минут) ничего не значит', () async {
      intents.intent = intent(AccountIntentKind.link);
      now = t0.add(AccountIntent.ttl + const Duration(seconds: 1));

      expect(
        await firstEvent(AccountFailureKind.identityAlreadyExists),
        isNull,
      );
    });

    test('ровно 15 минут ещё действует', () async {
      intents.intent = intent(AccountIntentKind.link);
      now = t0.add(AccountIntent.ttl);

      expect(
        await firstEvent(AccountFailureKind.identityAlreadyExists),
        AccountEvent.conflict,
      );
    });

    test(
      'намерение из будущего (часы переведены назад): игнорируется',
      () async {
        intents.intent = intent(AccountIntentKind.link);
        now = t0.subtract(const Duration(minutes: 1));

        expect(
          await firstEvent(AccountFailureKind.identityAlreadyExists),
          isNull,
        );
      },
    );

    test('намерение другого пользователя: игнорируется', () async {
      intents.intent = intent(AccountIntentKind.link, from: 'someone-else');

      expect(
        await firstEvent(AccountFailureKind.identityAlreadyExists),
        isNull,
      );
    });

    test('пользователь уже не анонимный: игнорируется', () async {
      intents.intent = intent(AccountIntentKind.link);
      auth.emitUser(google);

      expect(
        await firstEvent(AccountFailureKind.identityAlreadyExists),
        isNull,
      );
    });

    test('конфликт при входе с объединением (merge) невозможен: '
        'игнорируется', () async {
      intents.intent = intent(AccountIntentKind.merge);

      expect(
        await firstEvent(AccountFailureKind.identityAlreadyExists),
        isNull,
      );
      expect(intents.intent, isNotNull);
    });

    for (final kind in [AccountIntentKind.link, AccountIntentKind.merge]) {
      test('отказ в Google ($kind): cancelled, намерение сброшено', () async {
        intents.intent = intent(kind);

        expect(
          await firstEvent(AccountFailureKind.cancelled),
          AccountEvent.cancelled,
        );
        expect(intents.intent, isNull);
      });

      test(
        'другая ошибка возврата ($kind): failed, намерение сброшено',
        () async {
          intents.intent = intent(kind);

          expect(
            await firstEvent(AccountFailureKind.other),
            AccountEvent.failed,
          );
          expect(intents.intent, isNull);
        },
      );
    }
  });

  group('confirmMerge и decline', () {
    test('confirmMerge пишет merge от текущего анонимного пользователя и '
        'открывает вход', () async {
      intents.intent = intent(AccountIntentKind.link);

      expect(await service.confirmMerge(), isNull);

      expect(auth.signInCalls, 1);
      expect(auth.linkCalls, 0);
      expect(intents.intent, intent(AccountIntentKind.merge));
    });

    test('confirmMerge не из анонимного аккаунта: ничего не делает', () async {
      auth.emitUser(google);

      expect(await service.confirmMerge(), AccountEvent.failed);

      expect(auth.signInCalls, 0);
      expect(intents.intent, isNull);
    });

    test('ошибка открытия браузера сбрасывает merge', () async {
      auth.launchError = const NetworkError('offline');

      expect(await service.confirmMerge(), AccountEvent.network);
      expect(intents.intent, isNull);
    });

    test('decline сбрасывает намерение и ничего не открывает', () async {
      intents.intent = intent(AccountIntentKind.link);

      await service.decline();

      expect(intents.intent, isNull);
      expect(auth.signInCalls + auth.linkCalls, 0);
    });
  });
}
