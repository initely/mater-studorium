import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../domain/duel.dart';
import '../domain/duel_stage.dart';
import 'duel_cards_notifier.dart';
import 'format_duel_remaining.dart';
import 'isolate_name.dart';

/// Карточки дуэлей на главном (ТЗ §8.4, §8.2 п. 1): «Саша: твой ход», «Саша:
/// ждём ответа · осталось 2 д», «Саша ответил: посмотри результат». Пока
/// список не загрузился, при ошибке сети и когда карточек нет, не занимают
/// места.
class DuelCards extends ConsumerWidget {
  const DuelCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cards = ref.watch(duelCardsProvider).value;
    if (cards == null || cards.isEmpty) return const SizedBox.shrink();
    final now = ref.read(clockProvider)();
    return Column(
      key: const Key('home-duel-cards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.homeDuelsSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final duel in cards)
          _DuelCard(key: Key('home-duel-${duel.id}'), duel: duel, now: now),
      ],
    );
  }
}

class _DuelCard extends StatelessWidget {
  const _DuelCard({super.key, required this.duel, required this.now});

  final Duel duel;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stage = duelStageFor(duel, duel.statusAt(now));
    final name = duel.otherName == null ? null : isolateName(duel.otherName!);
    final title = switch (stage) {
      DuelStage.yourTurn =>
        name == null ? l10n.homeDuelYourTurn : l10n.homeDuelYourTurnNamed(name),
      DuelStage.waiting =>
        name == null ? l10n.homeDuelWaiting : l10n.homeDuelWaitingNamed(name),
      DuelStage.result =>
        name == null ? l10n.homeDuelResult : l10n.homeDuelResultNamed(name),
      DuelStage.expired => l10n.duelStatusExpired,
    };
    final subtitle = stage == DuelStage.result
        ? null
        : formatDuelRemaining(l10n, duel.remainingAt(now));
    final scheme = Theme.of(context).colorScheme;
    final emphasis = stage != DuelStage.waiting;
    return Card(
      color: emphasis ? scheme.primaryContainer : null,
      child: ListTile(
        minTileHeight: 64,
        leading: Icon(switch (stage) {
          DuelStage.yourTurn => Icons.play_arrow,
          DuelStage.result => Icons.emoji_events_outlined,
          _ => Icons.hourglass_empty,
        }),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/duels/${duel.id}'),
      ),
    );
  }
}
