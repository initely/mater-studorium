import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/report_reason.dart';
import '../domain/report_text.dart';
import 'report_form_notifier.dart';

/// Показывает шторку жалобы на вопрос (ТЗ M11): причины списком и
/// необязательный комментарий. Возвращает `true`, если жалоба записана.
Future<bool> showReportSheet(
  BuildContext context, {
  required String deckId,
  required int deckVersion,
  required String questionId,
  required String questionText,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ReportSheet(
      deckId: deckId,
      deckVersion: deckVersion,
      questionId: questionId,
      questionText: questionText,
    ),
  );
  return sent ?? false;
}

/// Содержимое шторки жалобы. После записи закрывается с `true`.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.deckId,
    required this.deckVersion,
    required this.questionId,
    required this.questionText,
  });

  final String deckId;
  final int deckVersion;
  final String questionId;
  final String questionText;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sent = await ref
        .read(reportFormProvider.notifier)
        .send(
          deckId: widget.deckId,
          deckVersion: widget.deckVersion,
          questionId: widget.questionId,
          questionText: widget.questionText,
          comment: _comment.text,
        );
    if (sent && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final form = ref.watch(reportFormProvider);
    final saving = form.status == ReportFormStatus.saving;
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
              l10n.reportSheetTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Text(l10n.reportSheetHint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          RadioGroup<ReportReason>(
            groupValue: form.reason,
            onChanged: (reason) {
              if (reason != null && !saving) {
                ref.read(reportFormProvider.notifier).select(reason);
              }
            },
            child: Column(
              children: [
                for (final reason in ReportReason.choosable)
                  RadioListTile<ReportReason>(
                    key: Key('report-reason-${reason.wire}'),
                    value: reason,
                    enabled: !saving,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_reasonLabel(l10n, reason)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('report-comment'),
            controller: _comment,
            enabled: !saving,
            maxLength: kMaxReportCommentChars,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: l10n.reportCommentLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          if (form.status == ReportFormStatus.failed) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.reportError,
                key: const Key('report-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('report-cancel'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 56)),
                  onPressed: saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(l10n.reportCancel),
                ),
              ),
              Expanded(
                child: FilledButton(
                  key: const Key('report-send'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: form.canSend ? _send : null,
                  child: Text(l10n.reportSend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _reasonLabel(AppLocalizations l10n, ReportReason reason) =>
    switch (reason) {
      ReportReason.wrongAnswer => l10n.reportReasonWrongAnswer,
      ReportReason.unclear => l10n.reportReasonUnclear,
      ReportReason.typo => l10n.reportReasonTypo,
      ReportReason.badSource => l10n.reportReasonBadSource,
      ReportReason.other => l10n.reportReasonOther,
      ReportReason.gradingDisagree => l10n.disagreeButton,
    };
