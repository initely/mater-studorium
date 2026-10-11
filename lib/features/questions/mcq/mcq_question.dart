import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../catalog/domain/payload_parts.dart';
import '../../catalog/domain/question_payload.dart';
import '../../grading/domain/mcq_grader.dart';
import '../question_prompt.dart';
import '../question_result.dart';
import 'option_order.dart';

/// Виджет `mcq` (ТЗ M4). Один верный ответ: тап по варианту сразу отвечает.
/// Несколько верных: отмечаем варианты и жмём «Ответить». После ответа
/// варианты заблокированы и подписаны (верно / неверно / верный ответ),
/// а не только окрашены.
class McqQuestion extends StatefulWidget {
  const McqQuestion({
    super.key,
    required this.prompt,
    required this.payload,
    required this.shuffleSeed,
    required this.onAnswered,
  });

  final String prompt;
  final McqPayload payload;
  final int shuffleSeed;
  final ValueChanged<QuestionResult> onAnswered;

  @override
  State<McqQuestion> createState() => _McqQuestionState();
}

class _McqQuestionState extends State<McqQuestion> {
  late final List<McqOption> _options = shuffledOptions(
    widget.payload.options,
    widget.shuffleSeed,
  );
  final Set<String> _selected = {};
  McqGrade? _grade;

  bool get _answered => _grade != null;

  void _onTap(String id) {
    if (_answered) return;
    if (widget.payload.multiple) {
      setState(
        () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
      );
    } else {
      setState(() => _selected.add(id));
      _answer();
    }
  }

  void _answer() {
    if (_answered || _selected.isEmpty) return;
    final grade = gradeMcq(widget.payload, _selected);
    setState(() => _grade = grade);
    widget.onAnswered(QuestionResult(outcome: grade.outcome));
  }

  _OptionVerdict _verdictOf(String id) {
    final grade = _grade;
    if (grade == null) return _OptionVerdict.none;
    if (grade.correctSelected.contains(id)) return _OptionVerdict.correct;
    if (grade.wrongSelected.contains(id)) return _OptionVerdict.wrong;
    if (grade.missed.contains(id)) return _OptionVerdict.missed;
    return _OptionVerdict.none;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final multiple = widget.payload.multiple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionPrompt(widget.prompt),
        if (multiple) ...[
          const SizedBox(height: 8),
          Text(
            l10n.mcqHintMultiple,
            key: const Key('mcq-hint-multiple'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 16),
        for (final option in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionTile(
              key: Key('mcq-option-${option.id}'),
              text: option.text,
              multiple: multiple,
              selected: _selected.contains(option.id),
              answered: _answered,
              verdict: _verdictOf(option.id),
              onTap: () => _onTap(option.id),
            ),
          ),
        if (multiple && !_answered) ...[
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('mcq-answer'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _selected.isEmpty ? null : _answer,
            child: Text(l10n.mcqAnswer),
          ),
        ],
      ],
    );
  }
}

enum _OptionVerdict { none, correct, wrong, missed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.text,
    required this.multiple,
    required this.selected,
    required this.answered,
    required this.verdict,
    required this.onTap,
  });

  final String text;
  final bool multiple;
  final bool selected;
  final bool answered;
  final _OptionVerdict verdict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final caption = switch (verdict) {
      _OptionVerdict.correct => l10n.mcqOptionCorrect,
      _OptionVerdict.wrong => l10n.mcqOptionWrong,
      _OptionVerdict.missed => l10n.mcqOptionMissed,
      _OptionVerdict.none => null,
    };
    final (Color background, Color foreground) = switch (verdict) {
      _OptionVerdict.correct || _OptionVerdict.missed => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      _OptionVerdict.wrong => (scheme.errorContainer, scheme.onErrorContainer),
      _OptionVerdict.none => (
        selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        selected ? scheme.onSecondaryContainer : scheme.onSurface,
      ),
    };
    final IconData icon = switch (verdict) {
      _OptionVerdict.correct => Icons.check_circle,
      _OptionVerdict.wrong => Icons.cancel,
      _OptionVerdict.missed => Icons.check_circle_outline,
      _OptionVerdict.none =>
        multiple
            ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
            : (selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
    };
    final label = caption == null ? text : '$text, $caption';

    return Semantics(
      container: true,
      excludeSemantics: true,
      enabled: !answered,
      button: !multiple,
      inMutuallyExclusiveGroup: !multiple,
      checked: multiple ? selected : null,
      selected: selected,
      label: label,
      onTap: answered ? null : onTap,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected || verdict != _OptionVerdict.none
                ? foreground
                : scheme.outlineVariant,
            width: selected || verdict != _OptionVerdict.none ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: answered ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text, style: TextStyle(color: foreground)),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
