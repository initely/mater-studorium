import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/duel_providers.dart';
import '../domain/duel.dart';
import '../domain/duel_stage.dart';
import '../domain/duel_status.dart';
import 'duel_code_card.dart';
import 'duel_deck_missing_card.dart';
import 'duel_detail_notifier.dart';
import 'duel_progress_notifier.dart';
import 'duel_result_notifier.dart';
import 'duel_result_view.dart';
import 'duel_status_text.dart';
import 'format_duel_remaining.dart';
import 'isolate_name.dart';

/// Экран дуэли: «твой ход» (кнопка «Играть»), «ждём соперника», результат
/// (счёт, время, ответы обоих, разбор), код и докачка колоды (ТЗ M10, §8.4).
///
/// Состояние читается при открытии, при возврате в приложение и с экрана
/// игры, по кнопке «Обновить» и по таймеру, пока дуэль ждёт соперника
/// (ТЗ §6.4: realtime в MVP не нужен; опрос проще и без утечек подписок).
class DuelScreen extends ConsumerStatefulWidget {
  const DuelScreen({super.key, required this.duelId});

  final String duelId;

  @override
  ConsumerState<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends ConsumerState<DuelScreen>
    with WidgetsBindingObserver {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final interval = ref.read(duelPollIntervalProvider);
    if (interval != null) {
      _poll = Timer.periodic(interval, (_) => _pollTick());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  /// Опрос только пока дуэль не закончена и не истекла: у завершённой
  /// состояние больше не меняется.
  void _pollTick() {
    final duel = ref.read(duelDetailProvider(widget.duelId)).value;
    if (duel == null) return;
    final status = duel.statusAt(ref.read(clockProvider)());
    if (status == DuelStatus.open || status == DuelStatus.active) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(duelProgressProvider(widget.duelId));
    await ref.read(duelDetailProvider(widget.duelId).notifier).refresh();
  }

  Future<void> _play() async {
    await context.push<Object?>('/duels/${widget.duelId}/play');
    if (mounted) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final duel = ref.watch(duelDetailProvider(widget.duelId));

    final Widget body;
    if (duel.value case final value?) {
      body = _Body(duel: value, onRefresh: _refresh, onPlay: _play);
    } else if (duel.hasValue) {
      body = Center(
        child: Text(l10n.duelNotFound, key: const Key('duel-not-found')),
      );
    } else if (duel.hasError) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(
                l10n.duelsLoadError,
                key: const Key('duel-error'),
                textAlign: TextAlign.center,
              ),
              FilledButton(
                key: const Key('duel-retry'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
                onPressed: () =>
                    ref.invalidate(duelDetailProvider(widget.duelId)),
                child: Text(l10n.duelsRetry),
              ),
            ],
          ),
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duelScreenTitle),
        actions: [
          IconButton(
            key: const Key('duel-refresh'),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.duelRefresh,
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.duel,
    required this.onRefresh,
    required this.onPlay,
  });

  final Duel duel;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    final status = duel.statusAt(now);
    final live = status == DuelStatus.open || status == DuelStatus.active;
    final progress = ref.watch(duelProgressProvider(duel.id)).value;
    final localDone =
        live && progress != null && duel.questionIds.every(progress.contains);
    final stage = duelStageFor(duel, status, localDone: localDone);
    final decks = ref.watch(downloadedDecksProvider).value;
    final deckMissing =
        live &&
        decks != null &&
        !decks.any((d) => d.id == duel.deckId && d.version >= duel.deckVersion);
    final name = duel.otherName;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      duelStatusText(l10n, duel, status, localDone: localDone),
                      key: const Key('duel-status'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (live)
                    Text(
                      formatDuelRemaining(l10n, duel.remainingAt(now)),
                      key: const Key('duel-remaining'),
                      textAlign: TextAlign.center,
                    ),
                  if (stage == DuelStage.yourTurn) ...[
                    if (duel.otherJoined)
                      Text(
                        name == null
                            ? l10n.duelStatusActive
                            : l10n.duelStatusActiveNamed(isolateName(name)),
                        key: const Key('duel-opponent'),
                        textAlign: TextAlign.center,
                      ),
                    Text(l10n.duelYourTurnBody, textAlign: TextAlign.center),
                    if (!deckMissing)
                      FilledButton(
                        key: const Key('duel-play'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 56),
                        ),
                        onPressed: onPlay,
                        child: Text(l10n.duelPlayButton),
                      ),
                  ],
                  if (stage == DuelStage.waiting) ...[
                    Text(
                      key: const Key('duel-waiting-body'),
                      name == null || !duel.otherJoined
                          ? l10n.duelWaitingBody
                          : l10n.duelWaitingBodyNamed(isolateName(name)),
                      textAlign: TextAlign.center,
                    ),
                    if (localDone && duel.myDoneAt == null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.duelSendingAnswers,
                          key: const Key('duel-sending'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                  if (status == DuelStatus.open &&
                      duel.isCreator &&
                      stage == DuelStage.waiting)
                    Text(l10n.duelStatusOpenBody, textAlign: TextAlign.center),
                  if (live && duel.isCreator && duel.code != null)
                    DuelCodeCard(code: duel.code!),
                  if (deckMissing)
                    DuelDeckMissingCard(
                      deckId: duel.deckId,
                      onDownloaded: () => unawaited(onRefresh()),
                    ),
                  if (stage == DuelStage.result) _Result(duelId: duel.id),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.duelId});

  final String duelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(duelResultProvider(duelId));
    if (result.value case final data?) {
      return DuelResultView(data: data);
    }
    if (result.hasError) {
      return Column(
        spacing: 12,
        children: [
          Text(
            l10n.duelResultError,
            key: const Key('duel-result-error'),
            textAlign: TextAlign.center,
          ),
          FilledButton(
            key: const Key('duel-result-retry'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
            onPressed: () => ref.invalidate(duelResultProvider(duelId)),
            child: Text(l10n.duelsRetry),
          ),
        ],
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
