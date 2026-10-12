import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../grading/domain/llm_consent.dart';
import '../../grading/presentation/llm_consent_notifier.dart';
import '../../reminders/presentation/reminder_tiles.dart';
import '../domain/user_settings.dart';
import 'settings_notifier.dart';
import 'stepper_tile.dart';

/// Настройки: лимит новых в день, размер сессии (T18) и напоминание (T19).
/// Привязка Google и «о приложении» добавят T21 и позже.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value ?? const UserSettings();
    final notifier = ref.read(settingsProvider.notifier);
    final consent = ref.watch(llmConsentProvider).value ?? LlmConsent.unknown;

    Future<void> save(Future<void> Function() write) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await write();
      } on AppError {
        messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.settingsSessionSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            StepperTile(
              key: const Key('settings-new-per-day'),
              title: l10n.settingsNewPerDay,
              value: settings.newPerDay,
              min: kMinNewPerDay,
              max: kMaxNewPerDay,
              onChanged: (v) => save(() => notifier.setNewPerDay(v)),
            ),
            StepperTile(
              key: const Key('settings-session-size'),
              title: l10n.settingsSessionSize,
              subtitle: l10n.settingsSessionSizeHint,
              value: settings.sessionSize,
              min: kMinSessionSize,
              max: kMaxSessionSize,
              step: kSessionSizeStep,
              onChanged: (v) => save(() => notifier.setSessionSize(v)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.settingsReminderSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            const ReminderTiles(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.settingsGradingSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            SwitchListTile(
              key: const Key('settings-llm-consent'),
              title: Text(l10n.settingsLlmConsentTitle),
              subtitle: Text(l10n.settingsLlmConsentSubtitle),
              // Пока не спрашивали, считаем «включено» только после явного
              // согласия: переключатель честно показывает, что уходит наружу.
              value: consent == LlmConsent.granted,
              onChanged: (on) => save(
                () => ref
                    .read(llmConsentProvider.notifier)
                    .set(on ? LlmConsent.granted : LlmConsent.declined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
