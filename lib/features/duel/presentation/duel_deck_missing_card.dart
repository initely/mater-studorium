import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../catalog/data/catalog_providers.dart';

/// «Колода этой дуэли не скачана»: докачка колоды, если вход по коду не успел
/// её скачать (нет сети) или у создателя версия новее. Без колоды играть
/// нельзя.
class DuelDeckMissingCard extends ConsumerStatefulWidget {
  const DuelDeckMissingCard({
    super.key,
    required this.deckId,
    this.onDownloaded,
  });

  final String deckId;

  /// Колода докачана (экран игры перечитывает дуэль и набор вопросов).
  final VoidCallback? onDownloaded;

  @override
  ConsumerState<DuelDeckMissingCard> createState() =>
      _DuelDeckMissingCardState();
}

class _DuelDeckMissingCardState extends ConsumerState<DuelDeckMissingCard> {
  var _busy = false;
  var _failed = false;

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await ref.read(catalogRepositoryProvider).download(widget.deckId);
      widget.onDownloaded?.call();
    } on AppError {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('duel-deck-missing'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              l10n.duelDeckMissing,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
            if (_failed)
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.duelDeckDownloadError,
                  key: const Key('duel-deck-error'),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            FilledButton(
              key: const Key('duel-deck-download'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: _busy ? null : _download,
              child: Text(
                _busy ? l10n.duelDeckDownloading : l10n.duelDeckDownload,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
