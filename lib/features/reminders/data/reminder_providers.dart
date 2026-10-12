import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/data/session_providers.dart';
import '../domain/notification_scheduler.dart';
import '../domain/reminder_service.dart';
import 'local_notification_scheduler.dart';
import 'noop_notification_scheduler.dart';

/// Платформа напоминаний: только Android (ТЗ M9, ADR-29). `Platform` читается
/// из `dart:io`, а не из `defaultTargetPlatform`: в `flutter test` последний
/// равен Android, и тесты полезли бы в настоящий плагин.
bool get _isAndroid => !kIsWeb && Platform.isAndroid;

/// Планировщик уведомлений платформы; в тестах подменяется fake.
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => _isAndroid
      ? LocalNotificationScheduler()
      : const NoopNotificationScheduler(),
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(
    scheduler: ref.watch(notificationSchedulerProvider),
    repository: ref.watch(sessionRepositoryProvider),
    offsetAt: ref.watch(utcOffsetProvider),
  ),
);
