import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/duel.dart';
import '../domain/duel_status.dart';
import 'duel_status_text.dart';
import 'format_duel_remaining.dart';
import 'isolate_name.dart';

/// Строка списка дуэлей: с кем и в каком состоянии.
class DuelTile extends StatelessWidget {
  const DuelTile({
    super.key,
    required this.duel,
    required this.now,
    required this.onTap,
  });

  final Duel duel;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = duel.statusAt(now);
    final title = switch ((duel.otherName, duel.otherJoined)) {
      (final String name, _) => l10n.duelWithName(isolateName(name)),
      (null, true) =>
        duel.isCreator ? l10n.duelOpponentUnnamed : l10n.duelCreatorUnnamed,
      (null, false) => l10n.duelWaitingTitle,
    };
    final active = status == DuelStatus.open || status == DuelStatus.active;
    final subtitle = [
      duelStatusText(l10n, duel, status),
      if (active) formatDuelRemaining(l10n, duel.remainingAt(now)),
    ].join(' · ');
    return ListTile(
      minTileHeight: 64,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
