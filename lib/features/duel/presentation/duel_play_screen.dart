import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/stable_seed.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../questions/question_request.dart';
import '../../questions/registry.dart';
import '../domain/duel_content.dart';
import 'duel_deck_missing_card.dart';
import 'duel_error_text.dart';
import 'duel_play_controller.dart';
import 'duel_stopwatch.dart';

/// Прохождение дуэли (ТЗ M10, §8.4): пять вопросов по порядку набора, виджеты
/// форматов из реестра, секундомер на вопрос, без панели оценки и без записи
/// в FSRS (ADR-16). Состояние держит `DuelPlayController`, поэтому поворот
/// экрана и уход в фон его не теряют; вопрос, на который уже отвечено
/// (на сервере или в очереди отправки), не показывается снова.
class DuelPlayScreen extends ConsumerStatefulWidget {
  const DuelPlayScreen({super.key, required this.duelId});

  final String duelId;

  @override
  ConsumerState<DuelPlayScreen> createState() => _DuelPlayScreenState();
}

class _DuelPlayScreenState extends ConsumerState<DuelPlayScreen> {
  @override
  void initState() {
    super.initState();
    // После первого кадра: к этому моменту build уже подписался на
    // autoDispose-провайдер.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(duelPlayProvider(widget.duelId).notifier).load();
      }
    });
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/duels/${widget.duelId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(duelPlayProvider(widget.duelId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duelPlayTitle),
        leading: IconButton(
          key: const Key('duel-play-close'),
          icon: const Icon(Icons.close),
          tooltip: l10n.duelOpenDuel,
          onPressed: _leave,
        ),
      ),
      body: SafeArea(child: _body(context, state)),
    );
  }

  Widget _body(BuildContext context, DuelPlayState state) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(duelPlayProvider(widget.duelId).notifier);
    switch (state.phase) {
      case DuelPlayPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case DuelPlayPhase.error:
        return _Message(
          key: const Key('duel-play-error'),
          text: state.error == null
              ? l10n.duelErrorGeneric
              : duelErrorText(l10n, state.error!),
          action: FilledButton(
            key: const Key('duel-play-retry'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
            onPressed: controller.load,
            child: Text(l10n.duelsRetry),
          ),
        );
      case DuelPlayPhase.notFound:
        return _Message(
          key: const Key('duel-play-not-found'),
          text: l10n.duelNotFound,
          action: _backButton(l10n),
        );
      case DuelPlayPhase.closed:
        return _Message(
          key: const Key('duel-play-closed'),
          text: l10n.duelPlayClosed,
          action: _backButton(l10n),
        );
      case DuelPlayPhase.done:
        return _Message(
          key: const Key('duel-play-done'),
          title: l10n.duelPlayDoneTitle,
          text: l10n.duelPlayDoneBody,
          action: _backButton(l10n),
        );
      case DuelPlayPhase.blocked:
        return _Blocked(
          state: state,
          onReload: controller.load,
          onSkip: controller.playWithoutUnavailable,
        );
      case DuelPlayPhase.playing:
        return _Playing(
          key: ValueKey('duel-${widget.duelId}-${state.index}'),
          duelId: widget.duelId,
          state: state,
          onLeave: _leave,
        );
    }
  }

  Widget _backButton(AppLocalizations l10n) => FilledButton(
    key: const Key('duel-play-back'),
    style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
    onPressed: _leave,
    child: Text(l10n.duelPlayBackToDuel),
  );
}

class _Message extends StatelessWidget {
  const _Message({super.key, this.title, required this.text, this.action});

  final String? title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            if (title != null)
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            Text(text, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    ),
  );
}

/// Часть вопросов набора недоступна на этом устройстве (или колоды нет):
/// обновить колоду или сыграть без них (ADR-36).
class _Blocked extends ConsumerStatefulWidget {
  const _Blocked({
    required this.state,
    required this.onReload,
    required this.onSkip,
  });

  final DuelPlayState state;
  final Future<void> Function() onReload;
  final Future<void> Function() onSkip;

  @override
  ConsumerState<_Blocked> createState() => _BlockedState();
}

class _BlockedState extends ConsumerState<_Blocked> {
  var _busy = false;
  var _failed = false;

  Future<void> _update() async {
    final duel = widget.state.duel;
    if (duel == null) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await ref.read(catalogRepositoryProvider).download(duel.deckId);
      if (mounted) await widget.onReload();
    } on AppError {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    if (state.deckMissing) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DuelDeckMissingCard(
              deckId: state.duel!.deckId,
              onDownloaded: widget.onReload,
            ),
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            key: const Key('duel-play-blocked'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.duelPlayBlockedTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text(
                l10n.duelPlayBlockedBody(state.unavailableCount),
                key: const Key('duel-play-blocked-body'),
                textAlign: TextAlign.center,
              ),
              if (_failed)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.duelPlayUpdateError,
                    key: const Key('duel-play-update-error'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              FilledButton(
                key: const Key('duel-play-update'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
                onPressed: _busy ? null : _update,
                child: Text(
                  _busy ? l10n.duelPlayUpdating : l10n.duelPlayUpdateDeck,
                ),
              ),
              OutlinedButton(
                key: const Key('duel-play-skip'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 56),
                ),
                onPressed: _busy ? null : widget.onSkip,
                child: Text(l10n.duelPlaySkip),
              ),
              Text(
                l10n.duelPlaySkipHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Playing extends ConsumerWidget {
  const _Playing({
    super.key,
    required this.duelId,
    required this.state,
    required this.onLeave,
  });

  final String duelId;
  final DuelPlayState state;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(duelPlayProvider(duelId).notifier);
    final DuelSlot slot = state.current!;
    final question = slot.content!.question;
    final module = ref
        .watch(questionRegistryProvider)
        .moduleFor(question.type)!;
    final isLast = !state.slots.any(
      (s) => s != slot && !state.answered.contains(s.questionId),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.duelPlayProgress(
                          state.index + 1,
                          state.slots.length,
                        ),
                        key: const Key('duel-play-progress'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  DuelStopwatch(
                    shownAt: state.shownAt!,
                    frozenMs: state.currentAnswered
                        ? state.lastDurationMs
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              module.build(
                context,
                QuestionRequest(
                  question: question,
                  // Один порядок вариантов у обоих участников: зерно от
                  // вопроса и дуэли, а не от даты и устройства.
                  shuffleSeed: stableSeed('${question.id}|$duelId'),
                  onAnswered: controller.onAnswered,
                  deckId: state.duel!.deckId,
                  deckVersion: state.duel!.deckVersion,
                ),
              ),
              if (state.saveFailed) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.duelPlaySaveError,
                    key: const Key('duel-play-save-error'),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('duel-play-save-retry'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: controller.retrySave,
                  child: Text(l10n.duelPlaySaveRetry),
                ),
              ],
              if (state.currentAnswered) ...[
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('duel-play-next'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: controller.next,
                  child: Text(isLast ? l10n.duelPlayFinish : l10n.duelPlayNext),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
