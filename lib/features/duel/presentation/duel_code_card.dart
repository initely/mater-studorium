import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/duel_code.dart';

/// Код приглашения крупно, с копированием кода и готового текста приглашения
/// (без внешних пакетов: системный share появится вместе с пакетом, когда он
/// понадобится, решение в ADR-35). Код озвучивается по знакам.
class DuelCodeCard extends StatelessWidget {
  const DuelCodeCard({super.key, required this.code});

  final String code;

  Future<void> _copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).duelCopied;
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              l10n.duelCodeLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge,
            ),
            Semantics(
              label: l10n.duelCodeSemantics(code.split('').join(' ')),
              child: ExcludeSemantics(
                child: SelectableText(
                  formatDuelCode(code),
                  key: const Key('duel-code'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    letterSpacing: 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            FilledButton.icon(
              key: const Key('duel-copy-code'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
              icon: const Icon(Icons.copy),
              label: Text(l10n.duelCopyCode),
              onPressed: () => _copy(context, code),
            ),
            OutlinedButton.icon(
              key: const Key('duel-copy-invite'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56)),
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n.duelCopyInvite),
              onPressed: () => _copy(context, l10n.duelInviteText(code)),
            ),
          ],
        ),
      ),
    );
  }
}
