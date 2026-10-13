import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../domain/display_name.dart';
import 'display_name_notifier.dart';

/// Поле «Твоё имя для соперника»: его увидит только соперник по дуэли (сервер
/// отдаёт имя участникам одной дуэли, остальным профиль закрыт). Можно не
/// заполнять.
class DuelNameField extends ConsumerStatefulWidget {
  const DuelNameField({super.key});

  @override
  ConsumerState<DuelNameField> createState() => _DuelNameFieldState();
}

class _DuelNameFieldState extends ConsumerState<DuelNameField> {
  final _controller = TextEditingController();
  var _filled = false;
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(displayNameProvider.notifier)
          .save(_controller.text);
      if (!mounted) return;
      // Показываем то, что реально сохранено (очищенное).
      _controller.text = saved ?? '';
      messenger.showSnackBar(SnackBar(content: Text(l10n.duelNameSaved)));
    } on AppError {
      messenger.showSnackBar(SnackBar(content: Text(l10n.duelNameError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Начальное значение подставляется один раз, чтобы не затирать ввод.
    ref.listen(displayNameProvider, (_, next) {
      if (!_filled && next.hasValue) {
        _filled = true;
        _controller.text = next.value ?? '';
      }
    });
    final current = ref.read(displayNameProvider);
    if (!_filled && current.hasValue) {
      _filled = true;
      _controller.text = current.value ?? '';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        TextField(
          key: const Key('duel-name-field'),
          controller: _controller,
          maxLength: kDisplayNameMaxLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.duelNameLabel,
            hintText: l10n.duelNameHint,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('duel-name-save'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _saving ? null : _save,
            child: Text(l10n.duelNameSave),
          ),
        ),
      ],
    );
  }
}
