import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../catalog/presentation/catalog_notifier.dart';
import '../../catalog/presentation/deck_tile.dart';
import '../../reminders/data/reminder_providers.dart';
import '../../reminders/presentation/reminder_tiles.dart';
import '../../settings/presentation/settings_notifier.dart';

enum _Step { welcome, session, reminder, deck }

/// Онбординг при первом запуске (ТЗ §8.1, M1): что это, как устроены сессии,
/// напоминание (только там, где оно работает: Android, T19), выбор и
/// скачивание первой колоды.
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

  /// Шаг напоминания пропускается на web и вне Android (ADR-29).
  List<_Step> get _steps => [
    _Step.welcome,
    _Step.session,
    if (ref.read(notificationSchedulerProvider).isSupported) _Step.reminder,
    _Step.deck,
  ];

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
    final steps = _steps;
    final current = steps[_step];
    final last = _step == steps.length - 1;
    final hasDeck = ref.watch(
      catalogProvider.select((s) => s.local.isNotEmpty),
    );

    final (title, body) = switch (current) {
      _Step.welcome => (
        l10n.onboardingWelcomeTitle,
        l10n.onboardingWelcomeBody,
      ),
      _Step.session => (
        l10n.onboardingSessionTitle,
        l10n.onboardingSessionBody,
      ),
      _Step.reminder => (
        l10n.onboardingReminderTitle,
        l10n.onboardingReminderBody,
      ),
      _Step.deck => (l10n.onboardingDeckTitle, l10n.onboardingDeckBody),
    };

    final header = [
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
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          l10n.onboardingStep(_step + 1, steps.length),
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
                  LinearProgressIndicator(value: (_step + 1) / steps.length),
                  const SizedBox(height: 16),
                  // Всё содержимое шага прокручивается вместе: на маленьком
                  // экране, в альбомной ориентации и при шрифте 200% ничего не
                  // обрезается, а кнопки ниже не двигаются.
                  Expanded(
                    child: switch (current) {
                      _Step.deck => _DeckChoice(header: header),
                      _Step.reminder => SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [...header, const ReminderTiles()],
                        ),
                      ),
                      _ => SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: header,
                        ),
                      ),
                    },
                  ),
                  const SizedBox(height: 8),
                  // Кнопки закреплены внизу и на всех шагах стоят на одних
                  // местах: основная выше, «Назад» под ней. На первом шаге
                  // место «Назад» остаётся пустым, поэтому «Далее» не прыгает.
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
                  const SizedBox(height: 4),
                  SizedBox(
                    key: const Key('onboarding-back-slot'),
                    height: 48,
                    child: _step > 0
                        ? TextButton(
                            key: const Key('onboarding-back'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => setState(() => _step--),
                            child: Text(l10n.onboardingBack),
                          )
                        : null,
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
  const _DeckChoice({required this.header});

  /// Заголовок и текст шага: прокручиваются вместе со списком колод.
  final List<Widget> header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(catalogProvider);
    final notifier = ref.read(catalogProvider.notifier);
    final entries = state.entries;

    return ListView(
      children: [
        ...header,
        if (entries.isEmpty && state.loading)
          const Center(child: CircularProgressIndicator()),
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
        if (entries.isEmpty && !state.loading && state.listError == null)
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
