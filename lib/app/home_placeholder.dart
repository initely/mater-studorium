import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_localizations.dart';

class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            FilledButton(
              onPressed: () => context.push('/decks'),
              child: Text(l10n.decksTitle),
            ),
            FilledButton(
              onPressed: () => context.go('/settings'),
              child: Text(l10n.settingsTitle),
            ),
          ],
        ),
      ),
    );
  }
}
