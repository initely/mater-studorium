import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import 'catalog_notifier.dart';
import 'catalog_state.dart';
import 'deck_tile.dart';

/// Экран «Колоды»: каталог сервера и скачанные колоды (ТЗ M2).
class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(catalogProvider);
    final notifier = ref.read(catalogProvider.notifier);
    final entries = state.entries;

    final Widget body;
    if (entries.isEmpty && state.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          // Тянуть для обновления можно и при пустом списке.
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.listError case final error?)
              _ListErrorBanner(error: error, onRetry: notifier.refresh),
            if (entries.isEmpty && state.listError == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(l10n.decksEmpty, key: const Key('decks-empty')),
                ),
              ),
            for (final entry in entries)
              DeckTile(
                key: ValueKey('deck-${entry.id}'),
                entry: entry,
                onDownload: () => notifier.download(entry.id),
                // Скачанную колоду можно открыть: прогресс и настройки (T18).
                onOpen: entry.status == DeckStatus.notDownloaded
                    ? null
                    : () => context.push('/decks/${entry.id}'),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.decksTitle)),
      body: body,
    );
  }
}

class _ListErrorBanner extends StatelessWidget {
  const _ListErrorBanner({required this.error, required this.onRetry});

  final AppError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('decks-list-error'),
      color: scheme.errorContainer,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error is NetworkError
                  ? l10n.decksListErrorNetwork
                  : l10n.decksListErrorGeneric,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('decks-retry'),
                onPressed: onRetry,
                child: Text(l10n.decksRetry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
