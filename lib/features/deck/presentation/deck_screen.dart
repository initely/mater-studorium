import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../catalog/presentation/deck_tile.dart' show deckErrorText;
import '../../settings/domain/user_settings.dart';
import '../../settings/presentation/settings_notifier.dart';
import '../../settings/presentation/stepper_tile.dart';
import '../data/deck_providers.dart';
import '../domain/deck_details.dart';
import '../domain/deck_progress.dart';
import 'deck_actions_notifier.dart';

/// Экран колоды (ТЗ §8.1): описание, число знаний, прогресс (новые /
/// изучаемые / выученные, ADR-27), «Начать по этой колоде», обновление,
/// лимит новых в день и удаление с устройства.
class DeckScreen extends ConsumerWidget {
  const DeckScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final details = ref.watch(deckDetailsProvider(deckId));

    final Widget body;
    String? title;
    if (details.value case final value?) {
      title = value.deck.title;
      body = _Content(details: value);
    } else if (details.hasError) {
      body = _Message(text: l10n.deckLoadError, key: const Key('deck-error'));
    } else if (details.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _Message(text: l10n.deckNotFound, key: const Key('deck-missing'));
    }

    return Scaffold(
      appBar: AppBar(title: Text(title ?? l10n.decksTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _Content extends ConsumerWidget {
  const _Content({required this.details});

  final DeckDetails details;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final deck = details.deck;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deckDeleteTitle),
        content: Text(l10n.deckDeleteBody(deck.title)),
        actions: [
          TextButton(
            key: const Key('deck-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.deckDeleteCancel),
          ),
          FilledButton(
            key: const Key('deck-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deckDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await ref
        .read(deckActionsProvider(deck.id).notifier)
        .delete();
    if (deleted && context.mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/decks');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deck = details.deck;
    final progress = details.progress;
    final actions = ref.watch(deckActionsProvider(deck.id));
    final settings = ref.watch(settingsProvider).value ?? const UserSettings();

    final String? status = switch (actions.result) {
      DeckUpdated(:final version) => l10n.deckUpdated(version),
      DeckUpToDate() => l10n.deckUpToDate,
      null => null,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              deck.description.isEmpty
                  ? l10n.deckNoDescription
                  : deck.description,
              key: const Key('deck-description'),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.deckVersionLine(deck.version, progress.total),
              key: const Key('deck-version'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _ProgressBlock(progress: progress),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('deck-start'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: progress.total == 0
                  ? null
                  : () => context.push('/session?deck=${deck.id}'),
              child: Text(l10n.deckStart),
            ),
            const SizedBox(height: 16),
            StepperTile(
              key: const Key('deck-new-per-day'),
              title: l10n.deckNewPerDay,
              subtitle: l10n.deckNewPerDayHint,
              value: settings.newPerDay,
              min: kMinNewPerDay,
              max: kMaxNewPerDay,
              onChanged: (v) => _saveNewPerDay(context, ref, v),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('deck-update'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: actions.busy
                  ? null
                  : () => ref
                        .read(deckActionsProvider(deck.id).notifier)
                        .checkUpdate(),
              child: Text(
                actions.busy ? l10n.deckUpdating : l10n.deckCheckUpdate,
              ),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  status,
                  key: const Key('deck-update-status'),
                  textAlign: TextAlign.center,
                ),
              ),
            if (actions.error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error is LocalStorageError
                      ? l10n.deckDeleteError
                      : deckErrorText(l10n, error),
                  key: const Key('deck-action-error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            TextButton.icon(
              key: const Key('deck-delete'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 56),
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: actions.busy
                  ? null
                  : () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.deckDelete),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNewPerDay(
    BuildContext context,
    WidgetRef ref,
    int value,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(settingsProvider.notifier).setNewPerDay(value);
    } on AppError {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
    }
  }
}

/// Полоса из трёх сегментов и легенда с числами: смысл передаётся значком и
/// подписью, а не только цветом; для скринридера — одна строка итога.
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.progress});

  final DeckProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = [
      (
        key: 'deck-progress-new',
        icon: Icons.fiber_new_outlined,
        label: l10n.deckNewLabel,
        count: progress.newCount,
        color: scheme.outline,
      ),
      (
        key: 'deck-progress-learning',
        icon: Icons.autorenew,
        label: l10n.deckLearningLabel,
        count: progress.learningCount,
        color: scheme.tertiary,
      ),
      (
        key: 'deck-progress-mastered',
        icon: Icons.check_circle_outline,
        label: l10n.deckMasteredLabel,
        count: progress.masteredCount,
        color: scheme.primary,
      ),
    ];

    return Semantics(
      container: true,
      label: l10n.deckProgressSemantics(
        progress.newCount,
        progress.learningCount,
        progress.masteredCount,
      ),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deckProgressTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (progress.total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      for (final r in rows)
                        if (r.count > 0)
                          Expanded(
                            flex: r.count,
                            child: ColoredBox(color: r.color),
                          ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  key: Key(r.key),
                  children: [
                    Icon(r.icon, color: r.color),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r.label)),
                    Text('${r.count}', style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
