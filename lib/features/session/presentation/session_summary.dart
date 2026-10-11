import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/session_state.dart';

/// Итоги сессии. СЕЙЧАС ЗАГЛУШКА: только число ответов и выход на главный.
///
/// Точка расширения для T14 (ТЗ §8.2, п. 5): здесь будут «повторено 14,
/// верно 11, следующее через 3 ч» (из `state.answers` и `state.queue`) и
/// «Ещё 5 минут». Экран сессии вызывает только этот виджет, остальное в нём
/// менять не нужно.
class SessionSummary extends StatelessWidget {
  const SessionSummary({super.key, required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
                l10n.sessionSummaryReviewed(state.answers.length),
                key: const Key('session-summary-reviewed'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('session-home'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
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
