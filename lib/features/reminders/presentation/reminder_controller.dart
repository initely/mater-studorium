import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../../settings/presentation/settings_notifier.dart';
import '../data/reminder_providers.dart';
import '../domain/reminder_service.dart';
import '../domain/reminder_texts.dart';

/// Тексты уведомления из ARB. Приложение пока на одном языке (ru): если
/// локаль устройства не поддержана, берётся ru, как и в `MaterialApp`.
final reminderTextsProvider = Provider<ReminderTexts>((ref) {
  final device = PlatformDispatcher.instance.locale;
  final l10n = AppLocalizations.delegate.isSupported(device)
      ? lookupAppLocalizations(device)
      : lookupAppLocalizations(const Locale('ru'));
  return ReminderTexts(
    title: l10n.reminderNotificationTitle,
    body: l10n.reminderNotificationBody,
    channelName: l10n.reminderChannelName,
    channelDescription: l10n.reminderChannelDescription,
  );
});

/// Управляет напоминаниями (ТЗ M9, T19): включение и время из настроек,
/// разрешение на уведомления, перепланирование. Состояние — итог последнего
/// перепланирования ([ReminderStatus]); экран по нему объясняет, почему
/// напоминаний нет (разрешение отозвано, web).
///
/// Перепланирование вызывают: старт приложения, возврат в приложение и уход
/// в фон, смена настроек, конец сессии. Вызовы выстраиваются в очередь,
/// чтобы два одновременных не перемешали отмену и постановку.
class ReminderController extends Notifier<ReminderStatus> {
  Future<void> _queue = Future.value();

  @override
  ReminderStatus build() => ReminderStatus.idle;

  /// Пересчитывает расписание по текущим настройкам и данным. Не бросает:
  /// сбой платформы даёт [ReminderStatus.failed] без сообщения пользователю.
  Future<void> reschedule() {
    final run = _queue.then((_) => _run());
    _queue = run;
    return run;
  }

  Future<void> _run() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    if (!scheduler.isSupported) {
      if (ref.mounted) state = ReminderStatus.unsupported;
      return;
    }
    try {
      final settings = await ref.read(settingsProvider.future);
      if (!ref.mounted) return;
      final result = await ref
          .read(reminderServiceProvider)
          .reschedule(
            enabled: settings.reminderEnabled,
            minuteOfDay: settings.reminderMinuteOfDay,
            now: ref.read(clockProvider)(),
            texts: ref.read(reminderTextsProvider),
          );
      if (ref.mounted) state = result.status;
    } on Exception catch (e) {
      debugPrint('Напоминания не перепланированы: $e');
      if (ref.mounted) state = ReminderStatus.failed;
    }
  }

  /// Тумблер «Напоминать». Включение сначала просит системное разрешение
  /// (Android 13+), затем пишет настройку: отказ не мешает включить, но
  /// напоминаний не будет (`permissionDenied`), экран это объясняет.
  /// Ошибка записи настройки (`LocalStorageError`) уходит вызывающему.
  Future<void> setEnabled(bool enabled) async {
    final scheduler = ref.read(notificationSchedulerProvider);
    if (enabled && scheduler.isSupported) {
      try {
        await scheduler.initialize();
        await scheduler.requestPermission();
      } on AppError catch (e) {
        debugPrint('Разрешение на уведомления не запрошено: $e');
      }
    }
    await ref.read(settingsProvider.notifier).setReminderEnabled(enabled);
    await reschedule();
  }

  /// Новое время напоминания (минуты от местной полуночи).
  Future<void> setMinuteOfDay(int minuteOfDay) async {
    await ref
        .read(settingsProvider.notifier)
        .setReminderMinuteOfDay(minuteOfDay);
    await reschedule();
  }

  /// Системные настройки уведомлений приложения (после отказа в разрешении).
  Future<void> openSystemSettings() async {
    try {
      await ref.read(notificationSchedulerProvider).openSystemSettings();
    } on AppError catch (e) {
      debugPrint('Настройки уведомлений не открылись: $e');
    }
  }
}

final reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderStatus>(
      ReminderController.new,
    );
