import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/local_deck.dart';
import 'create_duel_notifier.dart';
import 'duel_code_card.dart';
import 'duel_error_text.dart';

/// Создание дуэли (ТЗ M10, §8.4): выбор скачанной колоды, 5 случайных
/// вопросов, код для друга. Играет создатель с экрана дуэли («К дуэли»).
class DuelCreateScreen extends ConsumerStatefulWidget {
  const DuelCreateScreen({super.key});

  @override
  ConsumerState<DuelCreateScreen> createState() => _DuelCreateScreenState();
}

class _DuelCreateScreenState extends ConsumerState<DuelCreateScreen> {
  String? _selectedDeckId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(createDuelProvider);
    final decks = ref.watch(downloadedDecksProvider);

    final Widget body;
    if (state.duel case final duel?) {
      body = ListView(
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
                    child: Text(
                      l10n.duelCreatedTitle,
                      key: const Key('duel-created'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Text(l10n.duelCreatedBody, textAlign: TextAlign.center),
                  if (duel.code case final code?) DuelCodeCard(code: code),
                  OutlinedButton(
                    key: const Key('duel-open'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 56),
                    ),
                    onPressed: () =>
                        context.pushReplacement('/duels/${duel.id}'),
                    child: Text(l10n.duelOpenDuel),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (decks.value case final list?) {
      final selected =
          _selectedDeckId ?? (list.length == 1 ? list.first.id : null);
      body = list.isEmpty
          ? _NoDecks()
          : _Picker(
              decks: list,
              selectedId: selected,
              busy: state.busy,
              errorText: state.error == null
                  ? null
                  : duelErrorText(l10n, state.error!),
              onSelect: (id) => setState(() => _selectedDeckId = id),
              onCreate: selected == null
                  ? null
                  : () =>
                        ref.read(createDuelProvider.notifier).create(selected),
            );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.duelCreateTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _NoDecks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              l10n.duelCreateNoDecks,
              key: const Key('duel-no-decks'),
              textAlign: TextAlign.center,
            ),
            FilledButton(
              key: const Key('duel-to-decks'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: () => context.push('/decks'),
              child: Text(l10n.duelCreateNoDecksAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.decks,
    required this.selectedId,
    required this.busy,
    required this.errorText,
    required this.onSelect,
    required this.onCreate,
  });

  final List<LocalDeck> decks;
  final String? selectedId;
  final bool busy;
  final String? errorText;
  final ValueChanged<String> onSelect;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.duelCreateChooseDeck,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final deck in decks)
                  Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: deck.id == selectedId,
                    child: ListTile(
                      key: ValueKey('duel-deck-${deck.id}'),
                      minTileHeight: 56,
                      selected: deck.id == selectedId,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: deck.id == selectedId
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ),
                      leading: Icon(
                        deck.id == selectedId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(deck.title),
                      subtitle: Text(deck.topic),
                      onTap: busy ? null : () => onSelect(deck.id),
                    ),
                  ),
                if (errorText != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      errorText!,
                      key: const Key('duel-create-error'),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                FilledButton(
                  key: const Key('duel-create-submit'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: busy ? null : onCreate,
                  child: Text(
                    busy ? l10n.duelCreateCreating : l10n.duelCreateAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
