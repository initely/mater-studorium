import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../catalog/domain/payload_parts.dart';
import '../../grading/domain/open_grade.dart';

/// Разбор открытого ответа после проверки (ТЗ §4.2, п. 7, §8.3): пункты
/// рубрики с отметками ✓ ½ ✗, комментарий модели, эталон и остаток дневных
/// проверок. [grade] `null` — ответ отсёк клиент (слишком короткий) или
/// проверки нет: показываем только эталон.
///
/// Тексты упущенных пунктов берутся из ответа сервера (`missed`); тексты
/// раскрытых — из локальной рубрики колоды по `id`. Вердикт рисует сессия
/// (`VerdictBanner`), не эта панель.
class OpenResultPanel extends StatelessWidget {
  const OpenResultPanel({
    super.key,
    required this.grade,
    required this.rubric,
    required this.referenceAnswer,
  });

  final OpenGrade? grade;
  final List<RubricPoint> rubric;
  final String referenceAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final grade = this.grade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (grade != null) ...[
          ..._points(context, l10n, theme, grade),
          if (grade.feedback.isNotEmpty) ...[
            const SizedBox(height: 12),
            Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.openFeedbackTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    grade.feedback,
                    key: const Key('open-feedback'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
        _ReferenceCard(text: referenceAnswer),
        if (grade?.remainingQuota case final left?) ...[
          const SizedBox(height: 8),
          Text(
            l10n.openQuotaRemaining(left),
            key: const Key('open-quota'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  List<Widget> _points(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    OpenGrade grade,
  ) {
    final missedById = {for (final m in grade.missed) m.id: m};
    final rubricById = {for (final r in rubric) r.id: r};
    // Нет статусов по пунктам (редкий ответ без разбора): хотя бы упущенное.
    final rows = grade.points.isNotEmpty
        ? [
            for (final (i, p) in grade.points.indexed)
              _PointRow(
                status: p.status,
                text:
                    missedById[p.id]?.text ??
                    rubricById[p.id]?.text ??
                    '${i + 1}',
                // Пометка «обязательный» нужна у упущенного, у раскрытого
                // пункта это шум.
                required:
                    p.status != PointStatus.hit &&
                    (missedById[p.id]?.required ??
                        rubricById[p.id]?.required ??
                        false),
              ),
          ]
        : [
            for (final m in grade.missed)
              _PointRow(status: m.status, text: m.text, required: m.required),
          ];
    if (rows.isEmpty) return const [];
    return [
      Semantics(
        header: true,
        child: Text(l10n.openRubricTitle, style: theme.textTheme.titleSmall),
      ),
      const SizedBox(height: 4),
      Column(key: const Key('open-points'), children: rows),
    ];
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.status,
    required this.text,
    required this.required,
  });

  final PointStatus status;
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String label) = switch (status) {
      PointStatus.hit => (
        Icons.check_circle,
        scheme.primary,
        l10n.openPointHit,
      ),
      PointStatus.partial => (
        Icons.timelapse,
        scheme.tertiary,
        l10n.openPointPartial,
      ),
      PointStatus.miss => (Icons.cancel, scheme.error, l10n.openPointMiss),
    };
    return Semantics(
      container: true,
      label: '$label: $text${required ? ', ${l10n.openPointRequired}' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: text),
                    if (required)
                      TextSpan(
                        text: ' · ${l10n.openPointRequired}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Эталонный ответ из локальной колоды (рубрика и эталон не уходят на
/// сервер: он берёт свою копию, ADR-31).
class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: const Key('open-reference'),
      color: scheme.secondaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.openReferenceTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
