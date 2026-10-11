import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/app/app.dart';
import 'package:mater_studorium/core/l10n/app_localizations.dart';

extension PumpApp on WidgetTester {
  /// Рисует [widget] внутри `ProviderScope` + `MaterialApp` (локаль ru, ARB).
  /// Для обычных виджетов и экранов, которым не нужен роутер.
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: widget,
        ),
      ),
    );
  }

  /// Рисует настоящее приложение [App] (MaterialApp.router + go_router).
  /// Для проверки навигации и экранов, использующих `context.go`.
  /// Роутер можно подменить через `routerProvider` в [overrides].
  Future<void> pumpRouterApp({List<Override> overrides = const []}) async {
    await pumpWidget(ProviderScope(overrides: overrides, child: const App()));
  }
}
