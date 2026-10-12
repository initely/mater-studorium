import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../grading/domain/open_answer_limits.dart';

/// Поле открытого ответа со счётчиком (ТЗ §8.3). Длина — в единицах UTF-16,
/// как считает сервер (`kMaxOpenAnswerChars`), поэтому свой форматтер, а не
/// `maxLength` (тот считает графемы: 2000 эмодзи не влезли бы в контракт).
class OpenAnswerInput extends StatelessWidget {
  const OpenAnswerInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Идёт диктовка, проверка или ответ уже принят.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final atLimit = value.text.length >= kMaxOpenAnswerChars;
        final counter = l10n.openCounter(
          value.text.length,
          kMaxOpenAnswerChars,
        );
        return TextField(
          key: const Key('open-input'),
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          minLines: 3,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: const [_Utf16LengthFormatter()],
          decoration: InputDecoration(
            labelText: l10n.openAnswerLabel,
            hintText: l10n.openAnswerHint,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            // Счётчик с текстом и семантикой, цвет предела не единственный
            // признак: сам текст показывает «2000 из 2000».
            counter: Semantics(
              liveRegion: atLimit,
              child: Text(
                counter,
                key: const Key('open-counter'),
                style: TextStyle(color: atLimit ? scheme.error : null),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Обрезает ввод и вставку до лимита контракта, не разрывая суррогатную пару.
class _Utf16LengthFormatter extends TextInputFormatter {
  const _Utf16LengthFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= kMaxOpenAnswerChars) return newValue;
    final clamped = clampOpenAnswer(newValue.text);
    return TextEditingValue(
      text: clamped,
      selection: TextSelection.collapsed(
        offset: newValue.selection.baseOffset.clamp(0, clamped.length),
      ),
    );
  }
}
