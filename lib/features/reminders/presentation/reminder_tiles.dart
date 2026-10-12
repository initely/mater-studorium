import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../settings/domain/user_settings.dart';
import '../../settings/presentation/settings_notifier.dart';
import '../data/reminder_providers.dart';
import '../domain/reminder_service.dart';
import 'reminder_controller.dart';

/// Показывает выбор времени. В тестах подменяется, чтобы не водить пальцем
/// по циферблату.
typedef TimePicker = Future<TimeOfDay?> Function(
  BuildContext context,
  TimeOfDay initial,
  String help,
);

final timePickerProvider = Provider<TimePicker>(
  (ref) =>
      (context, initial, help) => showTimePicker(
        context: context,
        initialTime: initial,
        helpText: help,
      ),
);

/// Тумблер и время ежедневного напоминания (ТЗ M9, §8.1): общий для
/// настроек и онбординга. На платформе без напоминаний (web) тумблер
/// выключен, и сказано почему. Если напоминание включено, а системное
/// разрешение не дано, рядом объяснение и кнопка в системные настройки.
class ReminderTiles extends ConsumerWidget {
  const ReminderTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final supported = ref.watch(notificationSchedulerProvider).isSupported;
    final settings = ref.watch(settingsProvider).value ?? const UserSettings();
    final status = ref.watch(reminderControllerProvider);
    final controller = ref.read(reminderControllerProvider.notifier);

    Future<void> save(Future<void> Function() write) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await write();
      } on AppError {
        messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
      }
    }

    Future<void> pickTime() async {
      final initial = TimeOfDay(
        hour: settings.reminderMinuteOfDay ~/ 60,
        minute: settings.reminderMinuteOfDay % 60,
      );
      final picked = await ref.read(timePickerProvider)(
        context,
        initial,
        l10n.reminderTimePickerHelp,
      );
      if (picked == null) return;
      await save(
        () => controller.setMinuteOfDay(picked.hour * 60 + picked.minute),
      );
    }

    if (!supported) {
      return SwitchListTile(
        key: const Key('reminder-switch'),
        title: Text(l10n.reminderSwitchTitle),
        subtitle: Text(
          l10n.reminderUnsupported,
          key: const Key('reminder-unsupported'),
        ),
        value: false,
        onChanged: null,
      );
    }

    final enabled = settings.reminderEnabled;
    final time = TimeOfDay(
      hour: settings.reminderMinuteOfDay ~/ 60,
      minute: settings.reminderMinuteOfDay % 60,
    );
    final timeText = MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return Column(
      children: [
        SwitchListTile(
          key: const Key('reminder-switch'),
          title: Text(l10n.reminderSwitchTitle),
          subtitle: Text(l10n.reminderSwitchSubtitle),
          value: enabled,
          onChanged: (value) => save(() => controller.setEnabled(value)),
        ),
        ListTile(
          key: const Key('reminder-time'),
          enabled: enabled,
          title: Text(l10n.reminderTimeTitle),
          trailing: Text(
            timeText,
            key: const Key('reminder-time-value'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          onTap: enabled ? pickTime : null,
        ),
        if (enabled && status == ReminderStatus.permissionDenied)
          Padding(
            key: const Key('reminder-permission-denied'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.reminderPermissionDenied),
                TextButton(
                  key: const Key('reminder-open-settings'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: controller.openSystemSettings,
                  child: Text(l10n.reminderOpenSettings),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
