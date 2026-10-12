import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

/// Числовая настройка со значением и кнопками «−» и «+» (IconButton, 48 dp
/// с подсказками для скринридера). Значение выведено текстом.
class StepperTile extends StatelessWidget {
  const StepperTile({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final int step;

  /// Новое значение уже в границах [min]..[max].
  final ValueChanged<int> onChanged;

  void _change(int delta) => onChanged((value + delta).clamp(min, max));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('stepper-decrease'),
            icon: const Icon(Icons.remove),
            tooltip: l10n.settingsDecrease,
            onPressed: value > min ? () => _change(-step) : null,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              key: const Key('stepper-value'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const Key('stepper-increase'),
            icon: const Icon(Icons.add),
            tooltip: l10n.settingsIncrease,
            onPressed: value < max ? () => _change(step) : null,
          ),
        ],
      ),
    );
  }
}
