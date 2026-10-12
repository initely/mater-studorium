import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../srs/domain/rating.dart';
import '../../srs/presentation/rating_label.dart';
import '../domain/report_text.dart';

/// Выбор в шторке «не согласен»: оценка, которую пользователь считает верной,
/// и необязательный комментарий.
class DisagreeChoice {
  const DisagreeChoice({required this.rating, this.comment});

  final Rating rating;
  final String? comment;
}

/// Показывает шторку «Не согласен с оценкой ИИ» (ТЗ M11): [verdictLabel] —
/// вердикт словами («Верно», «Неверно», …), [suggested] — оценка, которую
/// предлагал ИИ (её выбрать нельзя: пользователь с ней не согласен).
/// Возвращает выбор или `null`, если шторку закрыли.
Future<DisagreeChoice?> showDisagreeSheet(
  BuildContext context, {
  required String verdictLabel,
  required Rating suggested,
}) => showModalBottomSheet<DisagreeChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      DisagreeSheet(verdictLabel: verdictLabel, suggested: suggested),
);

class DisagreeSheet extends StatefulWidget {
  const DisagreeSheet({
    super.key,
    required this.verdictLabel,
    required this.suggested,
  });

  final String verdictLabel;
  final Rating suggested;

  @override
  State<DisagreeSheet> createState() => _DisagreeSheetState();
}

class _DisagreeSheetState extends State<DisagreeSheet> {
  final _comment = TextEditingController();
  Rating? _rating;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final options = [
      for (final r in Rating.values)
        if (r != widget.suggested) r,
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.disagreeSheetTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.disagreeSheetBody(widget.verdictLabel),
            key: const Key('disagree-body'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              l10n.disagreeRatingLabel,
              style: theme.textTheme.titleMedium,
            ),
          ),
          RadioGroup<Rating>(
            groupValue: _rating,
            onChanged: (rating) => setState(() => _rating = rating),
            child: Column(
              children: [
                for (final rating in options)
                  RadioListTile<Rating>(
                    key: Key('disagree-rating-${rating.name}'),
                    value: rating,
                    contentPadding: EdgeInsets.zero,
                    title: Text(ratingLabel(l10n, rating)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('disagree-comment'),
            controller: _comment,
            maxLength: kMaxReportCommentChars,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: l10n.reportCommentLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('disagree-cancel'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 56)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.reportCancel),
                ),
              ),
              Expanded(
                child: FilledButton(
                  key: const Key('disagree-send'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: _rating == null
                      ? null
                      : () => Navigator.of(context).pop(
                          DisagreeChoice(
                            rating: _rating!,
                            comment: _comment.text,
                          ),
                        ),
                  child: Text(l10n.disagreeSend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
