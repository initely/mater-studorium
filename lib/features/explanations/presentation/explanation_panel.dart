import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../catalog/domain/item_ref.dart';
import '../data/link_launcher.dart';
import '../domain/explanation.dart';
import '../domain/safe_link.dart';

/// Разбор по желанию (ТЗ M6, §4.4, §8.2, п. 3): две свёрнутые кнопки
/// «Коротко» и «Подробнее». «Подробнее» — markdown и список источников со
/// ссылками. Тексты написаны заранее и лежат в колоде.
///
/// Панель ничего не блокирует: она лишь раскрывается под панелью оценки и
/// не знает про оценку и «Дальше» (AC6.1). Ссылки открываются во внешнем
/// браузере только если это `https` (`parseSafeLink`), остальные показаны
/// текстом (AC6.2). Знание без разбора — тихая подпись вместо кнопок.
class ExplanationPanel extends ConsumerStatefulWidget {
  const ExplanationPanel({super.key, required this.explanation});

  final Explanation explanation;

  @override
  ConsumerState<ExplanationPanel> createState() => _ExplanationPanelState();
}

class _ExplanationPanelState extends ConsumerState<ExplanationPanel> {
  var _shortOpen = false;
  var _longOpen = false;
  final _shortKey = GlobalKey();
  final _longKey = GlobalKey();

  void _toggle({required bool isLong}) {
    setState(() {
      if (isLong) {
        _longOpen = !_longOpen;
      } else {
        _shortOpen = !_shortOpen;
      }
    });
    if (!(isLong ? _longOpen : _shortOpen)) return;
    // Раскрытый текст может оказаться ниже экрана.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = (isLong ? _longKey : _shortKey).currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  void _say(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(Uri uri) async {
    final launcher = ref.read(linkLauncherProvider);
    var opened = false;
    try {
      opened = await launcher(uri);
    } on Exception {
      opened = false;
    }
    if (!opened && mounted) {
      _say(AppLocalizations.of(context).explanationLinkFailed);
    }
  }

  /// Ссылка внутри текста разбора: открываем, только если это один из
  /// источников колоды (ТЗ AC6.2: «каждая ссылка — из `sources`»).
  void _onMarkdownLink(String? href) {
    final uri = href == null ? null : parseSafeLink(href);
    final allowed =
        uri != null &&
        widget.explanation.sources.any(
          (s) => parseSafeLink(s.url)?.toString() == uri.toString(),
        );
    if (allowed) {
      _open(uri);
    } else {
      _say(AppLocalizations.of(context).explanationLinkBlocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final explanation = widget.explanation;

    if (explanation.isEmpty) {
      return Semantics(
        container: true,
        child: Row(
          key: const Key('explanation-empty'),
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.explanationEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8,
          children: [
            if (explanation.hasShort)
              Expanded(
                child: _ToggleButton(
                  key: const Key('explanation-short-toggle'),
                  label: l10n.explanationShortToggle,
                  open: _shortOpen,
                  onPressed: () => _toggle(isLong: false),
                ),
              ),
            if (explanation.hasLong)
              Expanded(
                child: _ToggleButton(
                  key: const Key('explanation-long-toggle'),
                  label: l10n.explanationLongToggle,
                  open: _longOpen,
                  onPressed: () => _toggle(isLong: true),
                ),
              ),
          ],
        ),
        if (_shortOpen && explanation.hasShort)
          Padding(
            key: _shortKey,
            padding: const EdgeInsets.only(top: 12),
            child: _ExplanationCard(
              child: Text(
                explanation.short!,
                key: const Key('explanation-short'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        if (_longOpen && explanation.hasLong)
          Padding(
            key: _longKey,
            padding: const EdgeInsets.only(top: 12),
            child: _ExplanationCard(
              child: Column(
                key: const Key('explanation-long'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (explanation.long != null)
                    MarkdownBody(
                      data: explanation.long!,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ),
                      onTapLink: (_, href, _) => _onMarkdownLink(href),
                      // Картинки из текста не грузим: разбор — только текст.
                      imageBuilder: (_, _, alt) => Text(alt ?? ''),
                    ),
                  if (explanation.sources.isNotEmpty)
                    _Sources(sources: explanation.sources, onOpen: _open),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    super.key,
    required this.label,
    required this.open,
    required this.onPressed,
  });

  final String label;
  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onPressed,
        icon: Icon(open ? Icons.expand_less : Icons.expand_more),
        label: Text(label),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.sources, required this.onOpen});

  final List<ItemRef> sources;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('explanation-sources'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.explanationSourcesTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (var i = 0; i < sources.length; i++)
          _SourceTile(index: i, source: sources[i], onOpen: onOpen),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.index,
    required this.source,
    required this.onOpen,
  });

  final int index;
  final ItemRef source;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final url = source.url.trim();
    final link = parseSafeLink(url);
    return Column(
      key: Key('explanation-source-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Text(
          source.sourceTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (source.license.trim().isNotEmpty)
          Text(
            l10n.explanationLicense(source.license),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        if (source.quote.trim().isNotEmpty)
          Text(
            l10n.explanationQuote(source.quote),
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (url.isNotEmpty)
          SelectableText(
            url,
            key: Key('explanation-source-$index-url'),
            style: theme.textTheme.bodySmall,
          ),
        if (link != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              link: true,
              button: true,
              label: l10n.explanationOpenSourceLabel(source.sourceTitle),
              onTap: () => onOpen(link),
              excludeSemantics: true,
              child: TextButton.icon(
                key: Key('explanation-source-$index-open'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => onOpen(link),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.explanationOpenSource),
              ),
            ),
          )
        else if (url.isNotEmpty)
          Text(
            l10n.explanationLinkNotHttps,
            key: Key('explanation-source-$index-not-https'),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
      ],
    );
  }
}
