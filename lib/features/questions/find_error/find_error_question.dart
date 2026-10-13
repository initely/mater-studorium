import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../catalog/domain/payload_parts.dart';
import '../../catalog/domain/question_payload.dart';
import '../../grading/domain/find_error_grader.dart';
import '../question_prompt.dart';
import '../question_result.dart';

/// Виджет `find_error` (ТЗ M4): строки кода (моноширинно, с номерами,
/// горизонтальный скролл без переноса) или список утверждений. Тап
/// выделяет строку, не больше двух. После «Проверить» ошибочные строки
/// помечены и под ними показаны `line_explanations`.
class FindErrorQuestion extends StatefulWidget {
  const FindErrorQuestion({
    super.key,
    required this.prompt,
    required this.payload,
    required this.onAnswered,
  });

  final String prompt;
  final FindErrorPayload payload;
  final ValueChanged<QuestionResult> onAnswered;

  @override
  State<FindErrorQuestion> createState() => _FindErrorQuestionState();
}

enum _Mark { none, found, wrong, missed }

class _FindErrorQuestionState extends State<FindErrorQuestion> {
  final Set<int> _selected = {};
  FindErrorGrade? _grade;

  bool get _answered => _grade != null;
  bool get _isCode => widget.payload.mode == FindErrorMode.code;

  void _toggle(int number) {
    if (_answered) return;
    setState(() {
      if (_selected.contains(number)) {
        _selected.remove(number);
      } else if (_selected.length < kFindErrorMaxSelection) {
        _selected.add(number);
      }
    });
  }

  void _check() {
    if (_answered || _selected.isEmpty) return;
    final grade = gradeFindError(widget.payload, _selected);
    setState(() => _grade = grade);
    widget.onAnswered(
      QuestionResult(
        outcome: grade.outcome,
        answer: {'lines': _selected.toList()..sort()},
      ),
    );
  }

  _Mark _markOf(int number) {
    final grade = _grade;
    if (grade == null) return _Mark.none;
    if (grade.found.contains(number)) return _Mark.found;
    if (grade.wrong.contains(number)) return _Mark.wrong;
    if (grade.missed.contains(number)) return _Mark.missed;
    return _Mark.none;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lines = widget.payload.lines;
    final rows = [
      for (var i = 0; i < lines.length; i++)
        _LineRow(
          key: Key('find-error-line-${i + 1}'),
          number: i + 1,
          text: lines[i],
          isCode: _isCode,
          selected: _selected.contains(i + 1),
          mark: _markOf(i + 1),
          answered: _answered,
          onTap: () => _toggle(i + 1),
        ),
    ];
    final grade = _grade;
    final explained = grade == null
        ? const <int>[]
        : ([...widget.payload.errorLines]..sort());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionPrompt(widget.prompt),
        const SizedBox(height: 8),
        Text(
          _isCode ? l10n.findErrorHintCode : l10n.findErrorHintText,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (_isCode)
          SingleChildScrollView(
            key: const Key('find-error-scroll'),
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        if (grade == null) ...[
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('find-error-check'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _selected.isEmpty ? null : _check,
            child: Text(l10n.findErrorCheck),
          ),
        ] else ...[
          const SizedBox(height: 16),
          for (final number in explained)
            if (widget.payload.lineExplanations[number] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.findErrorExplanation(
                    number,
                    widget.payload.lineExplanations[number]!,
                  ),
                  key: Key('find-error-explanation-$number'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
        ],
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    super.key,
    required this.number,
    required this.text,
    required this.isCode,
    required this.selected,
    required this.mark,
    required this.answered,
    required this.onTap,
  });

  final int number;
  final String text;
  final bool isCode;
  final bool selected;
  final _Mark mark;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color background, Color foreground) = switch (mark) {
      _Mark.found ||
      _Mark.missed => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _Mark.wrong => (scheme.errorContainer, scheme.onErrorContainer),
      _Mark.none => (
        selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        selected ? scheme.onSecondaryContainer : scheme.onSurface,
      ),
    };
    final caption = switch (mark) {
      _Mark.found => l10n.findErrorFound,
      _Mark.wrong => l10n.findErrorWrong,
      _Mark.missed => l10n.findErrorMissed,
      _Mark.none => null,
    };
    final base = selected
        ? l10n.findErrorLineSelected(number, text)
        : l10n.findErrorLine(number, text);
    final textStyle =
        (isCode
                ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
                : theme.textTheme.bodyLarge)
            ?.copyWith(color: foreground);
    final body = Text(text, style: textStyle, softWrap: !isCode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        container: true,
        excludeSemantics: true,
        button: !answered,
        enabled: !answered,
        selected: selected,
        label: caption == null ? base : '$base, $caption',
        onTap: answered ? null : onTap,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected || mark != _Mark.none
                  ? foreground
                  : scheme.outlineVariant,
              width: selected || mark != _Mark.none ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: answered ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$number',
                        textAlign: TextAlign.end,
                        style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isCode)
                      body
                    else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            body,
                            if (caption != null)
                              _caption(theme, caption, foreground),
                          ],
                        ),
                      ),
                    if (isCode && caption != null) ...[
                      const SizedBox(width: 12),
                      _caption(theme, caption, foreground),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _caption(ThemeData theme, String caption, Color color) => Text(
    caption,
    style: theme.textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.bold,
    ),
  );
}
