import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../../catalog/data/catalog_providers.dart';
import '../domain/duel.dart';
import '../domain/duel_status.dart';
import 'duel_code_card.dart';
import 'duel_deck_missing_card.dart';
import 'duel_detail_notifier.dart';
import 'duel_status_text.dart';
import 'format_duel_remaining.dart';

/// Состояние дуэли (T22): статус, сколько осталось, код для создателя, имя
/// соперника, докачка колоды. Игра и сравнение ответов — T23.
class DuelScreen extends ConsumerWidget {
  const DuelScreen({super.key, required this.duelId});

  final String duelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final duel = ref.watch(duelDetailProvider(duelId));

    final Widget body;
    if (duel.value case final value?) {
      body = _Body(duel: value, onRefresh: () => _refresh(ref));
    } else if (duel.hasValue) {
      body = Center(
        child: Text(l10n.duelNotFound, key: const Key('duel-not-found')),
      );
    } else if (duel.hasError) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(
                l10n.duelsLoadError,
                key: const Key('duel-error'),
                textAlign: TextAlign.center,
              ),
              FilledButton(
                key: const Key('duel-retry'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
                onPressed: () => ref.invalidate(duelDetailProvider(duelId)),
                child: Text(l10n.duelsRetry),
              ),
            ],
          ),
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duelScreenTitle),
        actions: [
          IconButton(
            key: const Key('duel-refresh'),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.duelRefresh,
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Future<void> _refresh(WidgetRef ref) =>
      ref.read(duelDetailProvider(duelId).notifier).refresh();
}

class _Body extends ConsumerWidget {
  const _Body({required this.duel, required this.onRefresh});

  final Duel duel;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    final status = duel.statusAt(now);
    final live = status == DuelStatus.open || status == DuelStatus.active;
    final decks = ref.watch(downloadedDecksProvider).value;
    final deckMissing =
        live &&
        decks != null &&
        !decks.any((d) => d.id == duel.deckId && d.version >= duel.deckVersion);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      duelStatusText(l10n, duel, status),
                      key: const Key('duel-status'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (live)
                    Text(
                      formatDuelRemaining(l10n, duel.remainingAt(now)),
                      key: const Key('duel-remaining'),
                      textAlign: TextAlign.center,
                    ),
                  if (status == DuelStatus.open && duel.isCreator)
                    Text(l10n.duelStatusOpenBody, textAlign: TextAlign.center),
                  if (live && duel.isCreator && duel.code != null)
                    DuelCodeCard(code: duel.code!),
                  if (deckMissing) DuelDeckMissingCard(deckId: duel.deckId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
