import '../domain/notification_scheduler.dart';
import '../domain/reminder_texts.dart';

/// Планировщик для платформ без локальных напоминаний (web, не Android):
/// ничего не делает и ничего не падает (ТЗ M9: на web в MVP их нет).
class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  bool get isSupported => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermission> permission() async =>
      NotificationPermission.denied;

  @override
  Future<NotificationPermission> requestPermission() async =>
      NotificationPermission.denied;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> replaceReminders(List<DateTime> at, ReminderTexts texts) async {}

  @override
  Future<String?> takeLaunchRoute() async => null;

  @override
  Stream<String> get taps => const Stream.empty();
}
