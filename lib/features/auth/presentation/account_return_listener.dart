import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'account_notifier.dart';

/// Адрес экрана настроек, где живёт блок «Аккаунт».
const kSettingsRoute = '/settings';

/// Ничего не рисует. Держит [accountProvider] живым с запуска, чтобы итог
/// возврата из Google (на web страница перезагружается, на Android приложение
/// возвращается из браузера) не потерялся, и открывает настройки, когда итог
/// надо показать: диалог конфликта или сообщение о результате (T21, ADR-34).
class AccountReturnListener extends ConsumerWidget {
  const AccountReturnListener({
    super.key,
    required this.router,
    required this.child,
  });

  /// Роутер приложения (передаётся из `App`, как в `ReminderCoordinator`).
  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(accountProvider.select((s) => s.needsAttention), (_, needs) {
      if (!needs) return;
      final location = router.routerDelegate.currentConfiguration.uri.path;
      if (location != kSettingsRoute) router.push(kSettingsRoute);
    });
    return child;
  }
}
