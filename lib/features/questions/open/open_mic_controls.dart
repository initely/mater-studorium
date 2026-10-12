import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../speech/domain/speech_service.dart';

/// Кнопка микрофона и состояния диктовки (ТЗ §8.3): слушаю, ошибка, нет
/// разрешения, нет поддержки, таймаут тишины, отмена. Диктовка только по тапу;
/// пока она идёт, на экране видно, что микрофон включён.
class OpenMicControls extends StatelessWidget {
  const OpenMicControls({
    super.key,
    required this.support,
    required this.listening,
    required this.failure,
    required this.enabled,
    required this.canOpenSettings,
    required this.onToggle,
    required this.onCancel,
    required this.onOpenSettings,
    this.dictated = false,
  });

  /// `null` — ещё проверяем.
  final SpeechSupport? support;
  final bool listening;
  final SpeechFailure? failure;

  /// Ответ можно редактировать (не идёт проверка, ответ не принят).
  final bool enabled;
  final bool canOpenSettings;
  final bool dictated;
  final VoidCallback onToggle;
  final VoidCallback onCancel;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unsupported =
        support == SpeechSupport.unsupported ||
        failure == SpeechFailure.unsupported;
    final tooltip = listening ? l10n.openMicStop : l10n.openMicStart;
    final message = _message(l10n, unsupported);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              key: const Key('open-mic'),
              tooltip: tooltip,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              isSelected: listening,
              icon: Icon(listening ? Icons.stop : Icons.mic),
              // Выключена, пока нет поддержки или идёт проверка. Во время
              // диктовки остаётся включённой: это «Закончить».
              onPressed:
                  unsupported || support == null || !(enabled || listening)
                  ? null
                  : onToggle,
            ),
            const SizedBox(width: 8),
            if (listening) ...[
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.openMicListening,
                    key: const Key('open-mic-listening'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              TextButton(
                key: const Key('open-mic-cancel'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onCancel,
                child: Text(l10n.openMicCancel),
              ),
            ],
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              key: const Key('open-mic-message'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: unsupported ? null : theme.colorScheme.error,
              ),
            ),
          ),
        ],
        if (failure == SpeechFailure.permissionDenied && canOpenSettings)
          TextButton(
            key: const Key('open-mic-settings'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onOpenSettings,
            child: Text(l10n.openMicOpenSettings),
          ),
      ],
    );
  }

  String? _message(AppLocalizations l10n, bool unsupported) {
    if (unsupported) return l10n.openMicUnsupported;
    return switch (failure) {
      SpeechFailure.permissionDenied =>
        canOpenSettings
            ? l10n.openMicPermissionDenied
            : l10n.openMicPermissionDeniedWeb,
      SpeechFailure.noSpeech => l10n.openMicNoSpeech,
      SpeechFailure.network => l10n.openMicNetwork,
      SpeechFailure.languageUnavailable => l10n.openMicLanguage,
      SpeechFailure.other => l10n.openMicError,
      SpeechFailure.unsupported => l10n.openMicUnsupported,
      null => dictated && !listening ? l10n.openMicEditHint : null,
    };
  }
}
