import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/errors/app_error.dart';
import '../domain/notification_scheduler.dart';
import '../domain/reminder_texts.dart';

/// Первый id напоминаний; ставим не больше [kReminderDays] подряд.
/// Другие уведомления (push дуэли, T24) берут ids вне этого диапазона.
const int kReminderIdBase = 19000;

const _kChannelId = 'daily_reminder';

/// Имя ресурса `drawable` (android/app/src/main/res/drawable).
const _kSmallIcon = 'ic_stat_reminder';

/// Android: локальные напоминания через `flutter_local_notifications`
/// (ADR-29).
///
/// - Время передаётся абсолютным моментом в UTC (`tz.UTC`): пояс устройства
///   уже учтён планировщиком, поэтому пакеты `flutter_timezone` и база
///   часовых поясов не нужны.
/// - Режим `inexactAllowWhileIdle`: не нужны `SCHEDULE_EXACT_ALARM` и
///   `USE_EXACT_ALARM`; показ может сдвинуться на минуты (Doze).
/// - После перезагрузки уведомления восстанавливает приёмник плагина
///   (`RECEIVE_BOOT_COMPLETED`).
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<void>? _initialization;
  var _launchTaken = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  bool get isSupported => true;

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> initialize() => _initialization ??= _initOnce();

  Future<void> _initOnce() async {
    try {
      await _guard(
        () => _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings(_kSmallIcon),
          ),
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            if (payload != null && payload.isNotEmpty) _taps.add(payload);
          },
        ),
      );
    } catch (_) {
      // Следующая попытка начнёт заново.
      _initialization = null;
      rethrow;
    }
  }

  @override
  Future<NotificationPermission> permission() => _guard(() async {
    final enabled = await _android?.areNotificationsEnabled();
    return enabled == true
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  });

  @override
  Future<NotificationPermission> requestPermission() => _guard(() async {
    await _android?.requestNotificationsPermission();
    return permission();
  });

  @override
  Future<void> openSystemSettings() =>
      _guard(() async => _android?.openAppNotificationSettings());

  @override
  Future<void> replaceReminders(List<DateTime> at, ReminderTexts texts) =>
      _guard(() async {
        for (var i = 0; i < kReminderDays; i++) {
          await _plugin.cancel(id: kReminderIdBase + i);
        }
        final details = NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            texts.channelName,
            channelDescription: texts.channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            category: AndroidNotificationCategory.reminder,
            autoCancel: true,
          ),
        );
        for (final (i, instant) in at.take(kReminderDays).indexed) {
          await _plugin.zonedSchedule(
            id: kReminderIdBase + i,
            title: texts.title,
            body: texts.body,
            scheduledDate: tz.TZDateTime.from(instant.toUtc(), tz.UTC),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: kReminderRoute,
          );
        }
      });

  @override
  Future<String?> takeLaunchRoute() => _guard(() async {
    if (_launchTaken) return null;
    _launchTaken = true;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload;
    return payload == null || payload.isEmpty ? null : payload;
  });

  /// Сбои платформы (`PlatformException` и т. п.) не должны ронять
  /// приложение: наверх идёт типизированная ошибка.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppError {
      rethrow;
    } on PlatformException catch (e) {
      throw UnexpectedError('ошибка уведомлений: ${e.code}', cause: e);
    } on Exception catch (e) {
      throw UnexpectedError('ошибка уведомлений', cause: e);
    }
  }
}
