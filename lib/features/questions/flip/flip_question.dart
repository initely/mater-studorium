import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../srs/domain/answer_outcome.dart';
import '../question_prompt.dart';
import '../question_result.dart';

/// Виджет `flip` (ТЗ M4): лицевая сторона, «Показать ответ», затем оборот.
/// Проверки нет: показ оборота — это «ответ», оценку ставит пользователь
/// (`AnswerOutcome.flip`, без подсказки).
class FlipQuestion extends StatefulWidget {
  const FlipQuestion({
    super.key,
    required this.prompt,
    required this.back,
    required this.onAnswered,
  });

  final String prompt;
  final String back;
  final ValueChanged<QuestionResult> onAnswered;

  @override
  State<FlipQuestion> createState() => _FlipQuestionState();
}

class _FlipQuestionState extends State<FlipQuestion> {
  var _revealed = false;

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    widget.onAnswered(const QuestionResult(outcome: AnswerOutcome.flip));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionPrompt(widget.prompt),
        const SizedBox(height: 16),
        if (_revealed)
          Card(
            key: const Key('flip-back'),
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                container: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.flipAnswerLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.back,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          FilledButton.tonal(
            key: const Key('flip-show'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
            onPressed: _reveal,
            child: Text(l10n.flipShowAnswer),
          ),
      ],
    );
  }
}
