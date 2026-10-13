import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import 'duel_action_state.dart';
import 'duel_error_text.dart';
import 'join_duel_notifier.dart';

/// Вход в дуэль по коду (ТЗ M10, AC10.2): поле кода, понятная ошибка для
/// неверного или просроченного кода. Колода докачивается при входе.
class DuelJoinScreen extends ConsumerStatefulWidget {
  const DuelJoinScreen({super.key});

  @override
  ConsumerState<DuelJoinScreen> createState() => _DuelJoinScreenState();
}

class _DuelJoinScreenState extends ConsumerState<DuelJoinScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => ref.read(joinDuelProvider.notifier).join(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(joinDuelProvider);
    final scheme = Theme.of(context).colorScheme;
    ref.listen<DuelActionState>(joinDuelProvider, (_, next) {
      if (next.duel case final duel?) {
        context.pushReplacement('/duels/${duel.id}');
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.duelJoinTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    TextField(
                      key: const Key('duel-code-field'),
                      controller: _controller,
                      autofocus: true,
                      enabled: !state.busy,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9 ]'),
                        ),
                        LengthLimitingTextInputFormatter(12),
                      ],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(letterSpacing: 4),
                      decoration: InputDecoration(
                        labelText: l10n.duelJoinCodeLabel,
                        hintText: l10n.duelJoinCodeHint,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (state.error case final error?)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          duelErrorText(l10n, error),
                          key: const Key('duel-join-error'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    FilledButton(
                      key: const Key('duel-join-submit'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 56),
                      ),
                      onPressed: state.busy ? null : _submit,
                      child: Text(
                        state.busy ? l10n.duelJoinJoining : l10n.duelJoinAction,
                      ),
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
