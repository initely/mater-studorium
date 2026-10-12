import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../settings/domain/user_settings.dart';
import '../../settings/presentation/settings_notifier.dart';
import '../data/reminder_providers.dart';
import '../domain/notification_scheduler.dart';
import 'reminder_controller.dart';

/// Связывает напоминания с жизнью приложения (T19), ничего не рисует.
///
/// - На старте готовит плагин, ставит расписание и открывает экран, если
///   приложение запущено тапом по уведомлению (холодный старт);
/// - перепланирует при возврате в приложение (часовой пояс, разрешение,
///   изменённое в системных настройках, `due` наступил) и при уходе в фон
///   (сессию могли закрыть на середине: сегодняшнее напоминание уже не
///   нужно);
/// - тап по уведомлению при запущенном приложении открывает сессию.
class ReminderCoordinator extends ConsumerStatefulWidget {
  const ReminderCoordinator({
    super.key,
    required this.router,
    required this.child,
  });

  /// Роутер приложения: открыть экран по тапу (передаётся из `App`, чтобы
  /// фича не зависела от `app/`).
  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<ReminderCoordinator> createState() =>
      _ReminderCoordinatorState();
}

class _ReminderCoordinatorState extends ConsumerState<ReminderCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_taps?.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    if (!scheduler.isSupported) return;
    try {
      await scheduler.initialize();
      if (!mounted) return;
      _taps = scheduler.taps.listen((route) => unawaited(_open(route)));
      final launch = await scheduler.takeLaunchRoute();
      if (!mounted) return;
      if (launch != null) await _open(launch);
    } on AppError catch (e) {
      debugPrint('Уведомления не запущены: $e');
    }
    if (mounted) {
      unawaited(ref.read(reminderControllerProvider.notifier).reschedule());
    }
  }

  /// Тап по напоминанию: главный экран, поверх него сессия, чтобы «назад»
  /// вело на главный (как после онбординга). До прохождения онбординга и
  /// когда сессия уже открыта, ничего не делаем.
  Future<void> _open(String route) async {
    if (route != kReminderRoute) return;
    final UserSettings settings;
    try {
      settings = await ref.read(settingsProvider.future);
    } on Exception {
      return;
    }
    if (!mounted || !settings.onboardingDone) return;
    final router = widget.router;
    final matches = router.routerDelegate.currentConfiguration;
    if (matches.isNotEmpty && matches.last.matchedLocation == kReminderRoute) {
      return;
    }
    router.go('/');
    unawaited(router.push<void>(route));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      unawaited(ref.read(reminderControllerProvider.notifier).reschedule());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
