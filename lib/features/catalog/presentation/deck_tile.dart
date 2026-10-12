import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import 'catalog_state.dart';

/// Строка колоды в списке: название, подпись, ошибка и действие. Общая для
/// каталога и онбординга.
class DeckTile extends StatelessWidget {
  const DeckTile({
    super.key,
    required this.entry,
    required this.onDownload,
    this.onOpen,
  });

  final DeckEntry entry;
  final VoidCallback onDownload;

  /// Тап по строке (экран колоды); `null` — строка не нажимается.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final count = entry.itemCount;
    final subtitle = count == null
        ? l10n.decksSubtitleLocal(entry.topic, entry.version)
        : l10n.decksSubtitle(entry.topic, entry.version, count);

    return ListTile(
      onTap: onOpen,
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          if (entry.error case final error?)
            Text(
              deckErrorText(l10n, error),
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
String deckErrorText(AppLocalizations l10n, AppError error) => switch (error) {
  NetworkError() => l10n.decksErrorNetwork,
  DeckFormatError() => l10n.decksErrorCorrupt,
  DeckSchemaTooNewError() => l10n.decksErrorSchemaTooNew,
  ItemIdCollisionError() ||
  QuestionIdCollisionError() => l10n.decksErrorCollision,
  DeckNotFoundError() => l10n.decksErrorNotFound,
  AuthError() ||
  UnexpectedError() ||
  SyncRejectedError() ||
  QuotaExceededError() ||
  ProviderUnavailableError() ||
  RequestRejectedError() ||
  LocalStorageError() => l10n.decksErrorGeneric,
};
