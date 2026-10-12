import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../catalog/presentation/catalog_notifier.dart';
import '../../catalog/presentation/deck_tile.dart';
import '../../settings/presentation/settings_notifier.dart';

const _kSteps = 3;

/// Онбординг при первом запуске (ТЗ §8.1, M1): что это, как устроены сессии,
/// выбор и скачивание первой колоды. Время напоминания сюда добавит T19.
/// Флаг «пройден» пишется в `app_settings` (ADR-27); роутер больше не
/// возвращает на этот экран.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  var _step = 0;
  var _finishing = false;

  Future<void> _finish({required bool startSession}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(settingsProvider.notifier).setOnboardingDone(true);
    } on AppError {
      // Не записали флаг: остаёмся, чтобы не крутить онбординг в цикле.
      if (mounted) setState(() => _finishing = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
      return;
    }
    router.go('/');
    // Главный под сессией: «назад» из сессии ведёт на главный без тупика.
    if (startSession) unawaited(router.push<void>('/session'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final last = _step == _kSteps - 1;
    final hasDeck = ref.watch(
      catalogProvider.select((s) => s.local.isNotEmpty),
    );

    final (title, body) = switch (_step) {
      0 => (l10n.onboardingWelcomeTitle, l10n.onboardingWelcomeBody),
      1 => (l10n.onboardingSessionTitle, l10n.onboardingSessionBody),
      _ => (l10n.onboardingDeckTitle, l10n.onboardingDeckBody),
    };

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          l10n.onboardingStep(_step + 1, _kSteps),
          key: const Key('onboarding-step'),
          style: theme.textTheme.titleSmall,
        ),
        actions: [
          if (!last)
            TextButton(
              key: const Key('onboarding-skip'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _finishing ? null : () => _finish(startSession: false),
              child: Text(l10n.onboardingSkip),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: (_step + 1) / _kSteps),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      key: const Key('onboarding-title'),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(body, key: const Key('onboarding-body')),
                  const SizedBox(height: 16),
                  Expanded(
                    child: last ? const _DeckChoice() : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  if (last)
                    FilledButton(
                      key: const Key('onboarding-finish'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 56),
                      ),
                      onPressed: _finishing
                          ? null
                          : () => _finish(startSession: hasDeck),
                      child: Text(
                        hasDeck
                            ? l10n.onboardingStartSession
                            : l10n.onboardingLater,
                      ),
                    )
                  else
                    FilledButton(
                      key: const Key('onboarding-next'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 56),
                      ),
                      onPressed: () => setState(() => _step++),
                      child: Text(l10n.onboardingNext),
                    ),
                  if (_step > 0)
                    TextButton(
                      key: const Key('onboarding-back'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => setState(() => _step--),
                      child: Text(l10n.onboardingBack),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Каталог колод с кнопками «Скачать» (тот же [DeckTile], что в «Колодах»).
class _DeckChoice extends ConsumerWidget {
  const _DeckChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(catalogProvider);
    final notifier = ref.read(catalogProvider.notifier);
    final entries = state.entries;

    if (entries.isEmpty && state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      children: [
        if (state.listError case final error?)
          Column(
            key: const Key('onboarding-list-error'),
            children: [
              Text(
                error is NetworkError
                    ? l10n.decksListErrorNetwork
                    : l10n.decksListErrorGeneric,
              ),
              TextButton(
                key: const Key('onboarding-retry'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: notifier.refresh,
                child: Text(l10n.decksRetry),
              ),
            ],
          ),
        if (entries.isEmpty && state.listError == null)
          Text(l10n.decksEmpty, key: const Key('onboarding-empty')),
        for (final entry in entries)
          DeckTile(
            key: ValueKey('deck-${entry.id}'),
            entry: entry,
            onDownload: () => notifier.download(entry.id),
          ),
      ],
    );
  }
}
