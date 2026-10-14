import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

/// «Дальше» после вопроса с автоматической оценкой (`mcq`, `cloze`, `order`,
/// `find_error`, `open` с оценкой моделью): оценку пользователь не выбирает,
/// она выведена из результата таблицей `suggestRating` (ТЗ §4.1).
class SessionNextButton extends StatelessWidget {
  const SessionNextButton({
    super.key,
    required this.enabled,
    required this.onNext,
  });

  /// `false` — идёт запись ответа.
  final bool enabled;

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('rating-next'),
      style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
      onPressed: enabled ? onNext : null,
      child: Text(AppLocalizations.of(context).ratingNext),
    );
  }
}
