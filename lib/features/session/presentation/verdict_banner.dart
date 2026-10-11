import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../srs/domain/answer_outcome.dart';

/// Вердикт под вопросом: иконка + слово + цвет (ТЗ §8.2, п. 3). Зависит
/// только от [AnswerOutcome], поэтому новые форматы выводят его без правок
/// сессии. Для самооценки (`flip`, `open` без вердикта) показывать нечего.
class VerdictBanner extends StatelessWidget {
  const VerdictBanner({super.key, required this.outcome});

  final AnswerOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, String text, Color background, Color foreground)? v =
        switch (outcome) {
          AnswerOutcome.autoCorrect || AnswerOutcome.llmCorrect => (
            Icons.check_circle,
            l10n.verdictCorrect,
            scheme.primaryContainer,
            scheme.onPrimaryContainer,
          ),
          AnswerOutcome.orderAdjacentSwap ||
          AnswerOutcome.clozeTypo ||
          AnswerOutcome.llmPartial => (
            Icons.adjust,
            l10n.verdictPartial,
            scheme.tertiaryContainer,
            scheme.onTertiaryContainer,
          ),
          AnswerOutcome.autoIncorrect || AnswerOutcome.llmIncorrect => (
            Icons.cancel,
            l10n.verdictIncorrect,
            scheme.errorContainer,
            scheme.onErrorContainer,
          ),
          AnswerOutcome.llmUnavailable || AnswerOutcome.flip => null,
        };
    if (v == null) return const SizedBox.shrink();
    final (icon, text, background, foreground) = v;
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: DecoratedBox(
        key: const Key('verdict-banner'),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 12),
              Text(
                text,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
