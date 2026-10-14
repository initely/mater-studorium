// Шаг 4 онбординга не показывает «нужна сеть», пока анонимный вход идёт
// (POLISH п. 1, 4): каталог запрашивается после входа сам.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/supabase/supabase_init.dart';
import 'package:mater_studorium/features/auth/presentation/auth_session_notifier.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/fake_supabase.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/unmount_app.dart';

void main() {
  testWidgets('шаг «Выберите колоду» до входа: индикатор вместо ошибки; после '
      'входа колоды появляются без «Повторить»', (tester) async {
    final remote = SessionGatedRemote(SampleRemote());
    await tester.pumpRouterApp(
      overrides: [
        ...appOverrides(memoryDb()),
        supabaseStatusProvider.overrideWith(ReadyStatus.new),
        authSessionProvider.overrideWith(FakeAuthSession.new),
        remoteByStatus(remote),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    // Индикатор загрузки анимируется бесконечно: pumpAndSettle здесь
    // «домотал» бы время за пределы ожидания входа.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Выберите колоду'), findsOneWidget);

    // Вход ещё не завершён: ошибки нет, запроса нет.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('onboarding-list-error')), findsNothing);
    expect(find.byKey(const Key('onboarding-retry')), findsNothing);
    expect(remote.fetches, 0);

    remote.signedIn = true;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    (container.read(authSessionProvider.notifier) as FakeAuthSession).set(
      AuthSessionStatus.signedIn,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-list-error')), findsNothing);
    expect(find.byKey(const Key('deck-action-sample')), findsOneWidget);
    expect(remote.fetches, 1);
    await tester.unmountApp();
  });
}
