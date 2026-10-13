import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../../duel/presentation/duel_cards.dart';
import '../../duel/presentation/my_duels_notifier.dart';
import '../../session/presentation/format_next_due.dart';
import '../../session/presentation/session_empty_view.dart' show kTakeNewCount;
import '../domain/home_stats.dart';
import 'home_notifier.dart';

/// Главный экран (ТЗ §8.1, §8.2 п. 1): «12 к повторению, 5 новых», кнопка
/// «Начать сессию (5 мин)», пустые состояния (§8.5), переходы в колоды и
/// настройки, карточки дуэлей (T23) под блоком счётчиков.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  ChangeNotifier? _routerDelegate;
  var _wasHome = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    final delegate = router?.routerDelegate;
    if (delegate != _routerDelegate) {
      _routerDelegate?.removeListener(_onRoute);
      _routerDelegate = delegate;
      delegate?.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routerDelegate?.removeListener(_onRoute);
    super.dispose();
  }

  /// Вернулись на главный из сессии, настроек и т. п.: счётчики устарели.
  /// Сама страница при `go('/')` не пересоздаётся, поэтому слушаем роутер.
  void _onRoute() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    // Для push-маршрутов `uri` остаётся адресом основы, поэтому берём
    // последнее совпадение: верхний экран стека.
    final isHome =
        router.routerDelegate.currentConfiguration.last.matchedLocation == '/';
    if (isHome && !_wasHome) _refreshAll();
    _wasHome = isHome;
  }

  /// Вернулись в приложение: время шло, `due` могло наступить.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  /// Счётчики и карточки дуэлей (соперник мог ответить, пока нас не было).
  void _refreshAll() {
    ref.read(homeProvider.notifier).refresh();
    ref.read(myDuelsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homeProvider);

    // Во время пересчёта остаётся прежнее значение: без мигания спиннера.
    final Widget body;
    if (home.value case final value?) {
      body = _Content(state: value);
    } else if (home.hasError) {
      body = _ErrorView(
        onRetry: () => ref.read(homeProvider.notifier).refresh(),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            key: const Key('home-settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              if (stats == null)
                const _NoDecks()
              else if (stats.hasWork)
                _Work(stats: stats)
              else
                _AllDone(stats: stats),
              const DuelCards(),
              const _DecksButton(),
              const _DuelsButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Work extends StatelessWidget {
  const _Work({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Semantics(
          container: true,
          label: l10n.homeStatsSemantics(stats.dueCount, stats.newCount),
          child: ExcludeSemantics(
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: _StatTile(
                    key: const Key('home-stat-due'),
                    icon: Icons.replay,
                    value: stats.dueCount,
                    label: l10n.homeDueLabel(stats.dueCount),
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    key: const Key('home-stat-new'),
                    icon: Icons.fiber_new_outlined,
                    value: stats.newCount,
                    label: l10n.homeNewLabel(stats.newCount),
                  ),
                ),
              ],
            ),
          ),
        ),
        FilledButton(
          key: const Key('home-start-session'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 64)),
          onPressed: () => context.push('/session'),
          child: Text(l10n.homeStartSession),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            Text('$value', style: theme.textTheme.displaySmall),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// «Всё повторено» (ТЗ §8.5) или, если в колодах нечего показывать вовсе,
/// нейтральное сообщение.
class _AllDone extends ConsumerWidget {
  const _AllDone({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final nextDue = stats.nextDue;
    final nothing = nextDue == null && !stats.moreNewAvailable;
    final next = nextDue == null
        ? null
        : formatNextDue(l10n, nextDue.difference(ref.read(clockProvider)()));

    return Column(
      key: Key(nothing ? 'home-nothing' : 'home-all-done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            nothing ? l10n.homeNothingTitle : l10n.sessionEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (nothing)
          Text(l10n.homeNothingBody, textAlign: TextAlign.center)
        else ...[
          if (next != null)
            Text(
              l10n.sessionEmptyNext(next),
              key: const Key('home-next'),
              textAlign: TextAlign.center,
            ),
          if (stats.moreNewAvailable) ...[
            Text(l10n.sessionEmptyNewLimit, textAlign: TextAlign.center),
            FilledButton(
              key: const Key('home-take-new'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: () => context.push('/session?extraNew=$kTakeNewCount'),
              child: Text(l10n.sessionTakeNew(kTakeNewCount)),
            ),
          ],
        ],
      ],
    );
  }
}

/// Нет скачанных колод: призыв скачать (ТЗ §8.5).
class _NoDecks extends StatelessWidget {
  const _NoDecks();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('home-no-decks'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.homeNoDecksTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Text(l10n.homeNoDecksBody, textAlign: TextAlign.center),
        FilledButton(
          key: const Key('home-download'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
          onPressed: () => context.push('/decks'),
          child: Text(l10n.homeNoDecksAction),
        ),
      ],
    );
  }
}

class _DecksButton extends StatelessWidget {
  const _DecksButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton(
      key: const Key('home-decks'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56)),
      onPressed: () => context.push('/decks'),
      child: Text(l10n.homeDecksButton),
    );
  }
}

class _DuelsButton extends StatelessWidget {
  const _DuelsButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton(
      key: const Key('home-duels'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56)),
      onPressed: () => context.push('/duels'),
      child: Text(l10n.homeDuelsButton),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              l10n.homeError,
              key: const Key('home-error'),
              textAlign: TextAlign.center,
            ),
            FilledButton(
              key: const Key('home-retry'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: onRetry,
              child: Text(l10n.homeRetry),
            ),
            const _DecksButton(),
          ],
        ),
      ),
    );
  }
}
