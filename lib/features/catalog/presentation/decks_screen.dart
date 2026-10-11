import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import 'catalog_notifier.dart';
import 'catalog_state.dart';

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
              _DeckTile(
                key: ValueKey('deck-${entry.id}'),
                entry: entry,
                onDownload: () => notifier.download(entry.id),
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

class _DeckTile extends StatelessWidget {
  const _DeckTile({super.key, required this.entry, required this.onDownload});

  final DeckEntry entry;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final count = entry.itemCount;
    final subtitle = count == null
        ? l10n.decksSubtitleLocal(entry.topic, entry.version)
        : l10n.decksSubtitle(entry.topic, entry.version, count);

    return ListTile(
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          if (entry.error case final error?)
            Text(
              _errorText(l10n, error),
              key: Key('deck-error-${entry.id}'),
              style: TextStyle(color: scheme.error),
            ),
        ],
      ),
      trailing: _action(l10n),
    );
  }

  Widget _action(AppLocalizations l10n) {
    final key = Key('deck-action-${entry.id}');
    if (entry.downloading) {
      return FilledButton.tonal(
        key: key,
        onPressed: null,
        child: Text(l10n.decksDownloading),
      );
    }
    return switch (entry.status) {
      DeckStatus.notDownloaded => FilledButton.tonal(
        key: key,
        onPressed: onDownload,
        child: Text(l10n.decksDownload),
      ),
      DeckStatus.updateAvailable => FilledButton(
        key: key,
        onPressed: onDownload,
        child: Text(l10n.decksUpdate),
      ),
      DeckStatus.downloaded => Chip(
        key: key,
        avatar: const Icon(Icons.check, size: 18),
        label: Text(l10n.decksDownloaded),
      ),
    };
  }
}

/// Текст ошибки скачивания колоды без технических подробностей.
String _errorText(AppLocalizations l10n, AppError error) => switch (error) {
  NetworkError() => l10n.decksErrorNetwork,
  DeckFormatError() => l10n.decksErrorCorrupt,
  DeckSchemaTooNewError() => l10n.decksErrorSchemaTooNew,
  ItemIdCollisionError() ||
  QuestionIdCollisionError() => l10n.decksErrorCollision,
  DeckNotFoundError() => l10n.decksErrorNotFound,
  AuthError() ||
  UnexpectedError() ||
  LocalStorageError() => l10n.decksErrorGeneric,
};
