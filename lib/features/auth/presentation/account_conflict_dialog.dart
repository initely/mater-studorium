import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

/// Диалог конфликта: этот Google уже привязан к другому профилю (T21,
/// ADR-34). Закрывается `true` («Войти и объединить») или `false`
/// («Отказаться»). Текст честно говорит, что прогресс этого устройства
/// объединится с прогрессом того аккаунта через синхронизацию (LWW).
class AccountConflictDialog extends StatelessWidget {
  const AccountConflictDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('account-conflict-dialog'),
      title: Text(l10n.accountConflictTitle),
      content: SingleChildScrollView(child: Text(l10n.accountConflictBody)),
      actions: [
        TextButton(
          key: const Key('account-conflict-decline'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.accountConflictDecline),
        ),
        FilledButton(
          key: const Key('account-conflict-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.accountConflictConfirm),
        ),
      ],
    );
  }
}
