import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import 'duel_name_field.dart';
import 'duel_tile.dart';
import 'my_duels_notifier.dart';

/// Экран «Дуэли» (ТЗ §8.1): создать, войти по коду, имя для соперника и
/// список своих дуэлей; игра и результат — на экране дуэли.
class DuelHubScreen extends ConsumerWidget {
  const DuelHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final duels = ref.watch(myDuelsProvider);
    final now = ref.read(clockProvider)();

    // После возврата с экрана создания, входа или дуэли список мог устареть.
    Future<void> open(String path) async {
      await context.push<Object?>(path);
      if (context.mounted) {
        unawaited(ref.read(myDuelsProvider.notifier).refresh());
      }
    }

    final Widget list;
    if (duels.value case final value?) {
      list = value.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.duelsEmpty,
                key: const Key('duels-empty'),
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              children: [
                for (final duel in value)
                  DuelTile(
                    key: ValueKey('duel-${duel.id}'),
                    duel: duel,
                    now: now,
                    onTap: () => open('/duels/${duel.id}'),
                  ),
              ],
            );
    } else if (duels.hasError) {
      list = Column(
        spacing: 8,
        children: [
          Text(
            l10n.duelsLoadError,
            key: const Key('duels-error'),
            textAlign: TextAlign.center,
          ),
          TextButton(
            key: const Key('duels-retry'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => ref.invalidate(myDuelsProvider),
            child: Text(l10n.duelsRetry),
          ),
        ],
      );
    } else {
      list = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.duelsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(myDuelsProvider.notifier).refresh(),
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
                      FilledButton(
                        key: const Key('duels-create'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 56),
                        ),
                        onPressed: () => open('/duels/new'),
                        child: Text(l10n.duelsCreate),
                      ),
                      OutlinedButton(
                        key: const Key('duels-join'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 56),
                        ),
                        onPressed: () => open('/duels/join'),
                        child: Text(l10n.duelsJoin),
                      ),
                      const DuelNameField(),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.duelsListTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      list,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
