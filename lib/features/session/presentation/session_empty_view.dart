import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../domain/session_queue.dart';
import 'format_next_due.dart';

/// Сколько новых знаний даёт «Взять новые» (ТЗ AC3.3, §8.5: «Взять 5 новых»).
const int kTakeNewCount = 5;

/// Пустая очередь (ТЗ AC3.3, §8.5): «Всё повторено 🎉 Следующее — через 3 ч»
/// и «Взять 5 новых», если они есть; без скачанных колод — «К колодам».
class SessionEmptyView extends ConsumerWidget {
  const SessionEmptyView({
    super.key,
    required this.queue,
    required this.onTakeNew,
  });

  final SessionQueue queue;

  /// «Взять новые»: перезапуск сессии с `extraNew` (экран).
  final VoidCallback onTakeNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reason = queue.emptyReason;
    final noContent = reason == EmptyQueueReason.noContent;
    final nextDue = queue.nextDue;
    final next = nextDue == null
        ? null
        : formatNextDue(l10n, nextDue.difference(ref.read(clockProvider)()));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Semantics(
                header: true,
                child: Text(
                  noContent
                      ? l10n.sessionNoContentTitle
                      : l10n.sessionEmptyTitle,
                  key: const Key('session-empty-title'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              if (noContent)
                Text(
                  l10n.sessionNoContentBody,
                  key: const Key('session-empty-body'),
                  textAlign: TextAlign.center,
                )
              else ...[
                if (reason == EmptyQueueReason.newLimitReached)
                  Text(
                    l10n.sessionEmptyNewLimit,
                    key: const Key('session-empty-new-limit'),
                    textAlign: TextAlign.center,
                  ),
                if (next != null)
                  Text(
                    l10n.sessionEmptyNext(next),
                    key: const Key('session-empty-next'),
                    textAlign: TextAlign.center,
                  ),
              ],
              const SizedBox(height: 12),
              if (noContent)
                FilledButton(
                  key: const Key('session-to-decks'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: () => context.push('/decks'),
                  child: Text(l10n.sessionToDecks),
                ),
              if (reason == EmptyQueueReason.newLimitReached)
                FilledButton(
                  key: const Key('session-take-new'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: onTakeNew,
                  child: Text(l10n.sessionTakeNew(kTakeNewCount)),
                ),
              OutlinedButton(
                key: const Key('session-home'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 56),
                ),
                onPressed: () => context.go('/'),
                child: Text(l10n.sessionHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
