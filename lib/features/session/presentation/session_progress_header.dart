import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../domain/session_state.dart';

/// Высота [SessionProgressHeader] для `AppBar.bottom`.
const double kSessionHeaderHeight = 44;

/// Тонкий прогресс-бар времени и подпись «Вопрос N из M · осталось м:сс»
/// (ТЗ §8.2, п. 2). Время считается от `clockProvider` и
/// `SessionState.remaining`; раз в секунду виджет перерисовывается сам
/// (`Timer.periodic`, отменяется в `dispose`). Само окончание сессии решает
/// `SessionController`: начатый вопрос можно дописать.
class SessionProgressHeader extends ConsumerStatefulWidget {
  const SessionProgressHeader({super.key, required this.state});

  final SessionState state;

  @override
  ConsumerState<SessionProgressHeader> createState() =>
      _SessionProgressHeaderState();
}

class _SessionProgressHeaderState extends ConsumerState<SessionProgressHeader> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _format(Duration d) {
    final seconds = (d.inMilliseconds / 1000).ceil();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = widget.state;
    final remaining = state.remaining(ref.read(clockProvider)());
    final timeUp = remaining == Duration.zero;
    final total = state.queue?.items.length ?? 0;
    final timeText = timeUp
        ? l10n.sessionTimeUp
        : l10n.sessionTimeLeft(_format(remaining));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: timeText,
            excludeSemantics: true,
            child: LinearProgressIndicator(
              key: const Key('session-time-bar'),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              value: remaining.inMilliseconds / kSessionDuration.inMilliseconds,
              color: timeUp ? theme.colorScheme.error : null,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.sessionProgress(
                  (state.index + 1).clamp(1, total == 0 ? 1 : total),
                  total,
                ),
                key: const Key('session-progress'),
                style: theme.textTheme.labelLarge,
              ),
              Flexible(
                child: Text(
                  timeText,
                  key: const Key('session-time'),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: timeUp ? theme.colorScheme.error : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
