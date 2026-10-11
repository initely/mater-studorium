import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/db/spike_database.dart';
import '../core/db/spike_providers.dart';
import '../core/l10n/app_localizations.dart';

class HomePlaceholder extends ConsumerWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // ВРЕМЕННО (T05): блок spike drift, удалить при T09.
    final notes = ref.watch(spikeNotesProvider).value ?? const <SpikeNote>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => context.go('/settings'),
              child: Text(l10n.settingsTitle),
            ),
          ),
          // --- spike drift (T05) ---
          ValueListenableBuilder<String?>(
            valueListenable: spikeWebStorage,
            builder: (context, impl, _) => impl == null
                ? const SizedBox.shrink()
                : Text(l10n.spikeStorage(impl)),
          ),
          OutlinedButton(
            onPressed: () =>
                addSpikeNote(ref, l10n.spikeNoteText(notes.length + 1)),
            child: Text(l10n.spikeAddNote),
          ),
          Expanded(
            child: notes.isEmpty
                ? Center(child: Text(l10n.spikeNoNotes))
                : ListView(
                    children: [
                      for (final n in notes)
                        ListTile(
                          title: Text(
                            l10n.spikeNoteLine(
                              n.body,
                              n.createdAt.toUtc().toIso8601String(),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
