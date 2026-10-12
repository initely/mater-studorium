import 'dart:async';

import 'package:mater_studorium/features/reminders/domain/notification_scheduler.dart';
import 'package:mater_studorium/features/reminders/domain/reminder_texts.dart';

/// Fake планировщика уведомлений: помнит, что поставили, и управляется из
/// теста (разрешение, тапы, холодный старт). Реальную доставку не проверяет.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({
    this.supported = true,
    this.granted = true,
    this.grantOnRequest = true,
    this.launchRoute,
  });

  final bool supported;

  /// Системное разрешение сейчас.
  bool granted;

  /// Что ответит диалог на `requestPermission` (дал ли пользователь).
  bool grantOnRequest;

  /// Тап, которым «запущено приложение» (холодный старт); отдаётся один раз.
  String? launchRoute;

  /// Поставленные сейчас напоминания (моменты UTC).
  List<DateTime> scheduled = [];
  ReminderTexts? texts;

  var initializeCalls = 0;
  var requestCalls = 0;
  var openSettingsCalls = 0;

  /// Сколько раз вызывали `replaceReminders`.
  var replaceCalls = 0;

  final _taps = StreamController<String>.broadcast();

  /// Пользователь тапнул по уведомлению при запущенном приложении.
  void tap(String route) => _taps.add(route);

  @override
  bool get isSupported => supported;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<NotificationPermission> permission() async =>
      granted ? NotificationPermission.granted : NotificationPermission.denied;

  @override
  Future<NotificationPermission> requestPermission() async {
    requestCalls++;
    if (grantOnRequest) granted = true;
    return permission();
  }

  @override
  Future<void> openSystemSettings() async => openSettingsCalls++;

  @override
  Future<void> replaceReminders(List<DateTime> at, ReminderTexts texts) async {
    replaceCalls++;
    scheduled = List.of(at);
    this.texts = texts;
  }

  @override
  Future<String?> takeLaunchRoute() async {
    final route = launchRoute;
    launchRoute = null;
    return route;
  }

  @override
  Stream<String> get taps => _taps.stream;
}
