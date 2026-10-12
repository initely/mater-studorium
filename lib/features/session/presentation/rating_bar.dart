import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../srs/domain/rating.dart';
import '../../srs/domain/rating_suggester.dart';
import '../../srs/presentation/rating_label.dart';

/// Панель оценки: четыре кнопки, предложенная выделена (заливка, галочка и
/// подпись «предложено», не только цвет), и «Дальше», которая принимает
/// предложенную (ТЗ §4.1, §8.2). Тап по любой кнопке оценки сразу
/// записывает её; другая, чем предложена, — переопределение
/// (`GradeSource.override`, считает `RatingSuggestion.sourceFor`).
class RatingBar extends StatelessWidget {
  const RatingBar({
    super.key,
    required this.suggestion,
    required this.enabled,
    required this.onRate,
  });

  final RatingSuggestion suggestion;

  /// `false` — идёт запись ответа, кнопки заблокированы.
  final bool enabled;

  final ValueChanged<Rating> onRate;

  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final suggested = suggestion.rating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.ratingPrompt, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 4),
        Text(
          suggested == null
              ? l10n.ratingChooseHint
              : l10n.ratingSuggestedHint(ratingLabel(l10n, suggested)),
          key: const Key('rating-hint'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 420 ? 4 : 2;
            final width =
                (constraints.maxWidth - _spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: _spacing,
              runSpacing: _spacing,
              children: [
                for (final rating in Rating.values)
                  SizedBox(
                    width: width,
                    child: _RatingButton(
                      key: Key('rating-${rating.name}'),
                      label: ratingLabel(l10n, rating),
                      suggested: rating == suggested,
                      onPressed: enabled ? () => onRate(rating) : null,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('rating-next'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
          onPressed: enabled && suggested != null
              ? () => onRate(suggested)
              : null,
          child: Text(l10n.ratingNext),
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    super.key,
    required this.label,
    required this.suggested,
    required this.onPressed,
  });

  final String label;
  final bool suggested;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const size = Size(48, 56);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggested) ...[
              const Icon(Icons.check, size: 18),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(label)),
          ],
        ),
        if (suggested)
          Text(
            l10n.ratingSuggested,
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
    final button = suggested
        ? FilledButton(
            style: FilledButton.styleFrom(minimumSize: size),
            onPressed: onPressed,
            child: content,
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: size),
            onPressed: onPressed,
            child: content,
          );
    return Semantics(
      label: suggested ? '$label, ${l10n.ratingSuggested}' : label,
      excludeSemantics: true,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: button,
    );
  }
}
