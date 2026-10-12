import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../data/session_providers.dart';
import '../domain/session_state.dart';
import '../domain/session_stats.dart';
import '../domain/upcoming_reviews.dart';
import 'format_next_due.dart';
import 'format_session_time.dart';

/// Итоги сессии (ТЗ §8.2, п. 5): сколько повторено, верно, неверно и по
/// самооценке, время, что повторить скоро, «Ещё 5 минут» и «На главную».
/// Берёт только то, что есть локально: ответы сессии (`state.answers`) и
/// расписание в БД.
class SessionSummary extends ConsumerWidget {
  const SessionSummary({
    super.key,
    required this.state,
    required this.onAnotherSession,
  });

  final SessionState state;

  /// «Ещё 5 минут»: новая сессия (экран).
  final VoidCallback onAnotherSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stats = SessionStats.from(
      state.answers,
      state.startedAt ?? ref.read(clockProvider)(),
    );
    // Расписание не нужно для итогов: ошибка или ожидание просто прячут блок.
    final upcoming = ref.watch(upcomingReviewsProvider).asData?.value;

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
                  l10n.sessionSummaryTitle,
                  key: const Key('session-summary-title'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Text(
                l10n.sessionSummaryReviewed(stats.reviewed),
                key: const Key('session-summary-reviewed'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (stats.reviewed > 0) ...[
                _StatRow(
                  key: const Key('session-summary-correct'),
                  icon: Icons.check_circle_outline,
                  text: l10n.sessionSummaryCorrect(stats.correct),
                ),
                _StatRow(
                  key: const Key('session-summary-incorrect'),
                  icon: Icons.highlight_off,
                  text: l10n.sessionSummaryIncorrect(stats.incorrect),
                ),
                if (stats.selfRated > 0)
                  _StatRow(
                    key: const Key('session-summary-self'),
                    icon: Icons.person_outline,
                    text: l10n.sessionSummarySelf(stats.selfRated),
                  ),
                _StatRow(
                  key: const Key('session-summary-time'),
                  icon: Icons.timer_outlined,
                  text: l10n.sessionSummaryTime(
                    formatSessionTime(l10n, stats.elapsed),
                  ),
                ),
              ],
              if (upcoming != null && !upcoming.isEmpty)
                _Upcoming(upcoming: upcoming),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('session-more'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
                onPressed: onAnotherSession,
                child: Text(l10n.sessionMore),
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

/// Строка итогов: иконка и текст (смысл не только в цвете).
class _StatRow extends StatelessWidget {
  const _StatRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(text)),
        ],
      ),
    );
  }
}

class _Upcoming extends ConsumerWidget {
  const _Upcoming({required this.upcoming});

  final UpcomingReviews upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    String when(DateTime due) => due.isAfter(now)
        ? formatNextDue(l10n, due.difference(now))
        : l10n.sessionSummaryUpcomingNow;

    final nextDue = upcoming.nextDue;
    return Column(
      key: const Key('session-summary-upcoming'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.sessionSummaryUpcomingTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (nextDue != null)
          Text(
            l10n.sessionEmptyNext(when(nextDue)),
            key: const Key('session-summary-next'),
          ),
        for (final item in upcoming.items)
          Text(l10n.sessionSummaryUpcomingItem(item.title, when(item.due))),
        if (upcoming.more > 0)
          Text(l10n.sessionSummaryUpcomingMore(upcoming.more)),
      ],
    );
  }
}
