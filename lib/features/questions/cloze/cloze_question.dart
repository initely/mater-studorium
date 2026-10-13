import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../catalog/domain/question_payload.dart';
import '../../grading/domain/cloze_grader.dart';
import '../question_result.dart';

/// Виджет `cloze` (ТЗ M4): текст вопроса с инлайн-полями вместо `{{id}}`.
/// Enter в последнем поле отправляет ответ, в остальных переводит фокус
/// дальше. После ответа поля заблокированы, каждый пропуск подписан
/// (верно / опечатка / неверно) и показывает принятый вариант.
class ClozeQuestion extends StatefulWidget {
  const ClozeQuestion({
    super.key,
    required this.prompt,
    required this.payload,
    required this.onAnswered,
  });

  final String prompt;
  final ClozePayload payload;
  final ValueChanged<QuestionResult> onAnswered;

  @override
  State<ClozeQuestion> createState() => _ClozeQuestionState();
}

class _ClozeQuestionState extends State<ClozeQuestion> {
  /// Порядок пропусков в тексте; пропуск без поля в тексте не создаём.
  late final List<String> _ids = [
    ...{
      for (final match in clozePlaceholder.allMatches(widget.prompt))
        match.group(1)!,
    },
  ];
  late final Map<String, TextEditingController> _controllers = {
    for (final id in _ids) id: TextEditingController(),
  };
  late final Map<String, FocusNode> _focus = {
    for (final id in _ids) id: FocusNode(),
  };
  ClozeGrade? _grade;

  bool get _answered => _grade != null;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_answered) return;
    final answers = {for (final id in _ids) id: _controllers[id]!.text.trim()};
    final grade = gradeCloze(widget.payload, answers);
    setState(() => _grade = grade);
    FocusScope.of(context).unfocus();
    widget.onAnswered(
      QuestionResult(
        outcome: grade.outcome,
        answer: {
          // Ответ дуэли ограничен по размеру: длинный ввод обрезаем.
          'answers': {
            for (final e in answers.entries)
              e.key: e.value.length > 80 ? e.value.substring(0, 80) : e.value,
          },
        },
      ),
    );
  }

  ClozeBlankGrade? _gradeOf(String id) {
    final grade = _grade;
    if (grade == null) return null;
    for (final blank in grade.blanks) {
      if (blank.id == id) return blank;
    }
    return null;
  }

  void _onFieldSubmitted(String id) {
    final index = _ids.indexOf(id);
    if (index < _ids.length - 1) {
      _focus[_ids[index + 1]]!.requestFocus();
    } else {
      _submit();
    }
  }

  List<InlineSpan> _spans(BuildContext context) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in clozePlaceholder.allMatches(widget.prompt)) {
      if (match.start > last) {
        spans.add(TextSpan(text: widget.prompt.substring(last, match.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _field(context, match.group(1)!),
        ),
      );
      last = match.end;
    }
    if (last < widget.prompt.length) {
      spans.add(TextSpan(text: widget.prompt.substring(last)));
    }
    return spans;
  }

  Widget _field(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final blank = _gradeOf(id);
    final index = _ids.indexOf(id);
    final color = switch (blank?.verdict) {
      null => null,
      ClozeBlankVerdict.correct => scheme.primary,
      ClozeBlankVerdict.typo => scheme.tertiary,
      ClozeBlankVerdict.wrong => scheme.error,
    };
    final isLast = index == _ids.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SizedBox(
        width: 140 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
        child: Align(
          heightFactor: 1,
          child: TextField(
            key: Key('cloze-field-$id'),
            controller: _controllers[id],
            focusNode: _focus[id],
            readOnly: _answered,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: isLast
                ? TextInputAction.done
                : TextInputAction.next,
            onSubmitted: (_) => _onFieldSubmitted(id),
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.clozeBlankLabel(index + 1),
              border: const OutlineInputBorder(),
              enabledBorder: color == null
                  ? null
                  : OutlineInputBorder(
                      borderSide: BorderSide(color: color, width: 2),
                    ),
              suffixIcon: switch (blank?.verdict) {
                null => null,
                ClozeBlankVerdict.correct => Icon(
                  Icons.check_circle,
                  color: color,
                ),
                ClozeBlankVerdict.typo => Icon(
                  Icons.check_circle_outline,
                  color: color,
                ),
                ClozeBlankVerdict.wrong => Icon(Icons.cancel, color: color),
              },
            ),
          ),
        ),
      ),
    );
  }

  String _caption(AppLocalizations l10n, ClozeBlankGrade blank) =>
      switch (blank.verdict) {
        ClozeBlankVerdict.correct => l10n.clozeBlankCorrect,
        ClozeBlankVerdict.typo => l10n.clozeBlankTypo(blank.expected),
        ClozeBlankVerdict.wrong => l10n.clozeBlankWrong(blank.expected),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final grade = _grade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(children: _spans(context)),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        if (grade == null)
          FilledButton(
            key: const Key('cloze-answer'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _submit,
            child: Text(l10n.clozeAnswer),
          )
        else
          for (final blank in grade.blanks)
            if (_ids.contains(blank.id))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_ids.indexOf(blank.id) + 1}. ${_caption(l10n, blank)}',
                  key: Key('cloze-caption-${blank.id}'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
      ],
    );
  }
}
