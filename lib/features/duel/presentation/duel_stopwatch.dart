import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import 'format_duel_time.dart';

/// Секундомер вопроса дуэли (ТЗ §8.4: «таймер от 0, без лимита»): идёт от
/// [shownAt] по `clockProvider`, после ответа замирает на [frozenMs]. Скринридеру
/// отдаётся одной подписью без живой области: каждую секунду он не говорит.
class DuelStopwatch extends ConsumerStatefulWidget {
  const DuelStopwatch({super.key, required this.shownAt, this.frozenMs});

  final DateTime shownAt;

  /// Время ответа; `null` — вопрос ещё без ответа, секундомер идёт.
  final int? frozenMs;

  @override
  ConsumerState<DuelStopwatch> createState() => _DuelStopwatchState();
}

class _DuelStopwatchState extends ConsumerState<DuelStopwatch> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(DuelStopwatch old) {
    super.didUpdateWidget(old);
    _syncTimer();
  }

  void _syncTimer() {
    if (widget.frozenMs == null) {
      _timer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final elapsed =
        widget.frozenMs ??
        ref.read(clockProvider)().difference(widget.shownAt).inMilliseconds;
    final text = formatDuelTime(elapsed);
    return Semantics(
      container: true,
      label: l10n.duelPlayTimerLabel(text),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const Icon(Icons.timer_outlined),
          Text(
            text,
            key: const Key('duel-stopwatch'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}
