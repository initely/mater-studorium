import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import 'report_sheet.dart';

/// Кнопка «⚑ Пожаловаться» под разбором (ТЗ M11): открывает шторку жалобы.
/// После записи жалобы становится недоступной («Жалоба отправлена»): вторая
/// жалоба на тот же вопрос от того же пользователя сервер не примет.
class ReportQuestionButton extends StatefulWidget {
  const ReportQuestionButton({
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
  State<ReportQuestionButton> createState() => _ReportQuestionButtonState();
}

class _ReportQuestionButtonState extends State<ReportQuestionButton> {
  var _sent = false;

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final thanks = AppLocalizations.of(context).reportThanks;
    final sent = await showReportSheet(
      context,
      deckId: widget.deckId,
      deckVersion: widget.deckVersion,
      questionId: widget.questionId,
      questionText: widget.questionText,
    );
    if (!sent) return;
    if (mounted) setState(() => _sent = true);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(thanks)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('report-button'),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: _sent ? null : _open,
        icon: Icon(_sent ? Icons.flag : Icons.flag_outlined),
        label: Text(_sent ? l10n.reportButtonSent : l10n.reportButton),
      ),
    );
  }
}
