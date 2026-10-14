import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../srs/domain/rating.dart';

/// Панель самооценки «Как хорошо вы это помнили»: две кнопки, «Не помню»
/// (`Rating.again`) и «Помню» (`Rating.good`). Показывается только там, где
/// ответ нечем проверить: карточка `flip` и `open`, когда оценка моделью
/// недоступна (ТЗ §4.1, строки с `grade_source = self`). У форматов с
/// автопроверкой панели нет, их оценку записывает `SessionNextButton`.
/// Тап сразу записывает оценку.
class RatingBar extends StatelessWidget {
  const RatingBar({super.key, required this.enabled, required this.onRate});

  /// `false` — идёт запись ответа, кнопки заблокированы.
  final bool enabled;

  final ValueChanged<Rating> onRate;

  static const _size = Size(48, 56);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.ratingPrompt,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _button(
                key: const Key('rating-again'),
                label: l10n.ratingForgot,
                rating: Rating.again,
                filled: false,
              ),
            ),
            Expanded(
              child: _button(
                key: const Key('rating-good'),
                label: l10n.ratingRemembered,
                rating: Rating.good,
                filled: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _button({
    required Key key,
    required String label,
    required Rating rating,
    required bool filled,
  }) {
    final onPressed = enabled ? () => onRate(rating) : null;
    return Semantics(
      label: label,
      excludeSemantics: true,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: filled
          ? FilledButton(
              key: key,
              style: FilledButton.styleFrom(minimumSize: _size),
              onPressed: onPressed,
              child: Text(label),
            )
          : OutlinedButton(
              key: key,
              style: OutlinedButton.styleFrom(minimumSize: _size),
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }
}
