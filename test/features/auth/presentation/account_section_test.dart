// Блок «Аккаунт» в настройках и диалог конфликта (T21, ADR-34), на
// фейковом репозитории: ключей Google в тестах нет и не нужно.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/l10n/app_localizations.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/features/auth/data/account_providers.dart';
import 'package:mater_studorium/features/auth/data/auth_providers.dart';
import 'package:mater_studorium/features/auth/domain/account_failure.dart';
import 'package:mater_studorium/features/auth/domain/account_intent.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';
import 'package:mater_studorium/features/auth/presentation/account_notifier.dart';
import 'package:mater_studorium/features/auth/presentation/account_section.dart';

import '../../../helpers/fake_account.dart';
import '../../../helpers/pump_app.dart';

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

  Future<void> pumpSection(WidgetTester tester, {bool configured = true}) =>
      tester.pumpApp(
        const Scaffold(body: SingleChildScrollView(child: AccountSection())),
        overrides: overrides(configured: configured),
      );

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AccountSection)));

  final linkButton = find.byKey(const Key('account-link-google'));
  final notice = find.byKey(const Key('account-notice'));
  final dialog = find.byKey(const Key('account-conflict-dialog'));

  Future<void> tapLink(WidgetTester tester) async {
    await tester.tap(linkButton);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('аноним: статус, пояснение и кнопка «Привязать Google»', (
    tester,
  ) async {
    await pumpSection(tester);
    final t = l10n(tester);

    expect(find.text(t.settingsAccountSection), findsOneWidget);
    expect(find.text(t.accountAnonymousTitle), findsOneWidget);
    expect(find.text(t.accountAnonymousSubtitle), findsOneWidget);
    expect(find.text(t.accountLinkButton), findsOneWidget);
    expect(notice, findsNothing);
  });

  testWidgets('кнопка не меньше 48 dp, раздел помечен заголовком', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSection(tester);
    final t = l10n(tester);

    final size = tester.getSize(linkButton);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(find.text(t.settingsAccountSection)),
      matchesSemantics(label: t.settingsAccountSection, isHeader: true),
    );
    expect(
      tester.getSemantics(linkButton),
      matchesSemantics(
        label: t.accountLinkButton,
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('тап: пишется намерение link и открывается браузер', (
    tester,
  ) async {
    await pumpSection(tester);

    await tapLink(tester);

    expect(auth.linkCalls, 1);
    expect(intents.intent?.kind, AccountIntentKind.link);
    expect(intents.intent?.fromUserId, 'anon-1');
    expect(notice, findsNothing);
    expect(
      tester.widget<FilledButton>(linkButton).onPressed,
      isNotNull,
      reason: 'кнопку можно нажать снова: браузер могли закрыть',
    );
  });

  for (final (name, error, text)
      in <(String, AppError, String Function(AppLocalizations))>[
        (
          'Google не настроен',
          const ProviderUnavailableError('off'),
          (t) => t.accountNoticeUnavailable,
        ),
        (
          'нет сети',
          const NetworkError('offline'),
          (t) => t.accountNoticeNetwork,
        ),
        (
          'отказ сервера',
          const AuthError('denied'),
          (t) => t.accountNoticeFailed,
        ),
      ]) {
    testWidgets('$name: понятное сообщение без технических деталей, '
        'намерение сброшено', (tester) async {
      auth.launchError = error;
      await pumpSection(tester);

      await tapLink(tester);

      expect(find.text(text(l10n(tester))), findsOneWidget);
      expect(find.textContaining('Error'), findsNothing);
      expect(intents.intent, isNull);
      expect(linkButton, findsOneWidget);
    });
  }

  testWidgets(
    'успешная привязка: тот же id, статус «Google: почта», кнопки нет',
    (tester) async {
      await pumpSection(tester);
      await tapLink(tester);

      auth.emitUser(
        const AuthUser(
          id: 'anon-1',
          isAnonymous: false,
          email: 'me@example.com',
        ),
      );
      await tester.pump();

      final t = l10n(tester);
      expect(find.text(t.accountLinkedTitle('me@example.com')), findsOneWidget);
      expect(find.text(t.accountNoticeLinked), findsOneWidget);
      expect(linkButton, findsNothing);
    },
  );

  testWidgets('привязан без почты в профиле: нейтральная подпись', (
    tester,
  ) async {
    auth = FakeAuthRepository(const AuthUser(id: 'g', isAnonymous: false));
    addTearDown(auth.dispose);
    await pumpSection(tester);

    expect(find.text(l10n(tester).accountLinkedNoEmailTitle), findsOneWidget);
    expect(linkButton, findsNothing);
  });

  testWidgets('отказ в Google: сообщение «ничего не изменилось»', (
    tester,
  ) async {
    await pumpSection(tester);
    await tapLink(tester);

    auth.emitFailure(AccountFailureKind.cancelled);
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n(tester).accountNoticeCancelled), findsOneWidget);
    expect(intents.intent, isNull);
    expect(find.text(l10n(tester).accountAnonymousTitle), findsOneWidget);
  });

  testWidgets('чужое событие без намерения экран не трогает', (tester) async {
    await pumpSection(tester);

    auth.emitFailure(AccountFailureKind.identityAlreadyExists);
    await tester.pump();
    await tester.pump();

    expect(dialog, findsNothing);
    expect(notice, findsNothing);
  });

  group('конфликт: этот Google уже используется', () {
    Future<void> conflict(WidgetTester tester) async {
      await pumpSection(tester);
      await tapLink(tester);
      auth.emitFailure(AccountFailureKind.identityAlreadyExists);
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('диалог предупреждает про объединение через синк (LWW) и '
        'даёт выбор', (tester) async {
      await conflict(tester);
      final t = l10n(tester);

      expect(dialog, findsOneWidget);
      expect(find.text(t.accountConflictTitle), findsOneWidget);
      expect(find.text(t.accountConflictBody), findsOneWidget);
      expect(t.accountConflictBody, contains('объединится'));
      expect(t.accountConflictBody, contains('более поздний'));
      expect(find.text(t.accountConflictConfirm), findsOneWidget);
      expect(find.text(t.accountConflictDecline), findsOneWidget);
      for (final key in [
        'account-conflict-confirm',
        'account-conflict-decline',
      ]) {
        expect(
          tester.getSize(find.byKey(Key(key))).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(
        auth.signInCalls,
        0,
        reason: 'без подтверждения ничего не открыто',
      );
    });

    testWidgets('отказ: ничего не меняется, намерение сброшено', (
      tester,
    ) async {
      await conflict(tester);

      await tester.tap(find.byKey(const Key('account-conflict-decline')));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(auth.signInCalls, 0);
      expect(intents.intent, isNull);
      expect(find.text(l10n(tester).accountAnonymousTitle), findsOneWidget);
      expect(linkButton, findsOneWidget);
    });

    testWidgets('подтверждение: пишется merge и открывается вход в '
        'существующий аккаунт', (tester) async {
      await conflict(tester);

      await tester.tap(find.byKey(const Key('account-conflict-confirm')));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      expect(auth.signInCalls, 1);
      expect(intents.intent?.kind, AccountIntentKind.merge);
      expect(intents.intent?.fromUserId, 'anon-1');

      // Вернулись из Google уже другим пользователем.
      auth.emitUser(
        const AuthUser(
          id: 'google-9',
          isAnonymous: false,
          email: 'old@example.com',
        ),
      );
      await tester.pump();
      await tester.pump();
      final t = l10n(tester);
      expect(
        find.text(t.accountLinkedTitle('old@example.com')),
        findsOneWidget,
      );
      expect(find.text(t.accountNoticeSignedInExisting), findsOneWidget);
      expect(linkButton, findsNothing);
    });

    testWidgets('вход в существующий аккаунт не открылся: сообщение, merge '
        'сброшен', (tester) async {
      await conflict(tester);
      auth.launchError = const NetworkError('offline');

      await tester.tap(find.byKey(const Key('account-conflict-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).accountNoticeNetwork), findsOneWidget);
      expect(intents.intent, isNull);
    });

    testWidgets('итог пришёл до открытия настроек (перезагрузка web): диалог '
        'показывается при открытии экрана', (tester) async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      container.read(accountProvider);
      intents.intent = AccountIntent(
        kind: AccountIntentKind.link,
        fromUserId: 'anon-1',
        createdAt: t0,
      );
      auth.emitFailure(AccountFailureKind.identityAlreadyExists);
      await tester.pump();
      await tester.pump();
      expect(container.read(accountProvider).phase, AccountPhase.conflict);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AccountSection()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(dialog, findsOneWidget);
    });
  });

  testWidgets('кнопка блокируется, пока открывается браузер', (tester) async {
    await pumpSection(tester);
    final gate = auth.hold();

    await tester.tap(linkButton);
    await tester.pump();

    expect(tester.widget<FilledButton>(linkButton).onPressed, isNull);
    expect(find.text(l10n(tester).accountLinkOpening), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<FilledButton>(linkButton).onPressed, isNotNull);
    expect(auth.linkCalls, 1);
  });

  testWidgets('сборка без бэкенда: сообщение, кнопки нет, ничего не падает', (
    tester,
  ) async {
    await pumpSection(tester, configured: false);

    expect(find.text(l10n(tester).accountNoBackend), findsOneWidget);
    expect(linkButton, findsNothing);
  });

  testWidgets(
    'анонимный вход ещё идёт: статус «Выполняется вход», кнопки нет',
    (tester) async {
      auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await pumpSection(tester);

      expect(find.text(l10n(tester).accountSigningIn), findsOneWidget);
      expect(linkButton, findsNothing);

      auth.emitUser(anon);
      await tester.pump();
      expect(linkButton, findsOneWidget);
    },
  );
}
