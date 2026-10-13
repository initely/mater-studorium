import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../catalog/domain/payload_parts.dart';
import '../../catalog/domain/question_payload.dart';
import '../../grading/domain/order_grader.dart';
import '../question_prompt.dart';
import '../question_result.dart';

/// Виджет `order` (ТЗ M4, AC4.3): шаги в перемешанном порядке, которые
/// можно перетаскивать за ручку или двигать кнопками ↑↓ (доступность и web).
/// После «Проверить» шаги на своих местах подписаны «Верно», остальные
/// показывают верное место.
class OrderQuestion extends StatefulWidget {
  const OrderQuestion({
    super.key,
    required this.prompt,
    required this.payload,
    required this.shuffleSeed,
    required this.onAnswered,
  });

  final String prompt;
  final OrderPayload payload;
  final int shuffleSeed;
  final ValueChanged<QuestionResult> onAnswered;

  @override
  State<OrderQuestion> createState() => _OrderQuestionState();
}

class _OrderQuestionState extends State<OrderQuestion> {
  late final List<OrderStep> _steps = shuffledSteps(
    widget.payload.steps,
    widget.shuffleSeed,
  );
  OrderGrade? _grade;

  bool get _answered => _grade != null;

  void _move(int from, int to) {
    if (_answered || to < 0 || to >= _steps.length) return;
    setState(() => _steps.insert(to, _steps.removeAt(from)));
  }

  void _check() {
    if (_answered) return;
    final ids = [for (final s in _steps) s.id];
    final grade = gradeOrder(widget.payload, ids);
    setState(() => _grade = grade);
    widget.onAnswered(
      QuestionResult(outcome: grade.outcome, answer: {'order': ids}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionPrompt(widget.prompt),
        const SizedBox(height: 8),
        Text(l10n.orderHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        ReorderableListView(
          key: const Key('order-list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: _move,
          children: [
            for (var i = 0; i < _steps.length; i++)
              _StepTile(
                key: ValueKey(_steps[i].id),
                step: _steps[i],
                index: i,
                total: _steps.length,
                answered: _answered,
                grade: _grade?.steps[i],
                onUp: () => _move(i, i - 1),
                onDown: () => _move(i, i + 1),
              ),
          ],
        ),
        if (!_answered) ...[
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('order-check'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _check,
            child: Text(l10n.orderCheck),
          ),
        ],
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.answered,
    required this.grade,
    required this.onUp,
    required this.onDown,
  });

  final OrderStep step;
  final int index;
  final int total;
  final bool answered;
  final OrderStepGrade? grade;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final verdict = grade;
    final (Color background, Color foreground) = switch (verdict?.isCorrect) {
      null => (scheme.surfaceContainerLow, scheme.onSurface),
      true => (scheme.primaryContainer, scheme.onPrimaryContainer),
      false => (scheme.errorContainer, scheme.onErrorContainer),
    };
    final caption = verdict == null
        ? null
        : verdict.isCorrect
        ? l10n.orderStepCorrect
        : l10n.orderStepWrong(verdict.correctPosition);
    final label = l10n.orderStepPosition(index + 1, total, step.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        label: caption == null ? label : '$label, $caption',
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Text(
                      '${index + 1}.',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.text,
                              style: TextStyle(color: foreground),
                            ),
                            if (caption != null)
                              Text(
                                caption,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: foreground,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!answered) ...[
                    IconButton(
                      key: Key('order-up-${step.id}'),
                      tooltip: l10n.orderMoveUp(step.text),
                      onPressed: index == 0 ? null : onUp,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      key: Key('order-down-${step.id}'),
                      tooltip: l10n.orderMoveDown(step.text),
                      onPressed: index == total - 1 ? null : onDown,
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ] else
                    Icon(
                      verdict!.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: foreground,
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
