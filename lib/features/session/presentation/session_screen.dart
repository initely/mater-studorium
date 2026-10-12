import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../domain/session_state.dart';
import 'session_controller.dart';
import 'session_empty_view.dart';
import 'session_progress_header.dart';
import 'session_question_step.dart';
import 'session_summary.dart';

/// Экран сессии на 5 минут (ТЗ M3, §8.2): прогресс и таймер сверху, вопрос
/// своего формата, после ответа вердикт и панель оценки; в конце — итоги
/// (`SessionSummary`) или пустое состояние (`SessionEmptyView`).
///
/// Сессию ведёт `SessionController` (autoDispose: уходим с экрана — состояние
/// сбрасывается, ответы уже в БД). Состояние живёт в провайдере и в `State`
/// виджетов вопроса, поэтому поворот экрана его не теряет.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  AppError? _startError;
  var _extraNew = 0;

  /// Идёт построение очереди: повторный запуск («Ещё 5 минут», двойной тап)
  /// игнорируется.
  var _starting = false;

  @override
  void initState() {
    super.initState();
    // После первого кадра: к этому моменту build уже подписался на
    // autoDispose-провайдер.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start({int extraNew = 0}) async {
    if (_starting) return;
    _starting = true;
    _extraNew = extraNew;
    if (_startError != null) setState(() => _startError = null);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .start(extraNew: extraNew);
    } on AppError catch (error) {
      if (mounted) setState(() => _startError = error);
    } finally {
      _starting = false;
    }
  }

  Future<void> _confirmExit() async {
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionExitConfirmTitle),
        content: Text(l10n.sessionExitConfirmBody),
        actions: [
          TextButton(
            key: const Key('session-exit-stay'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.sessionExitStay),
          ),
          FilledButton(
            key: const Key('session-exit-leave'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionExitLeave),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(sessionControllerProvider);
    final running = state.status == SessionStatus.running;

    return PopScope(
      // Идущую сессию закрываем только после подтверждения; итоги и пустые
      // состояния — свободно.
      canPop: !running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.sessionTitle),
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('session-close'),
            icon: const Icon(Icons.close),
            tooltip: l10n.sessionExit,
            onPressed: running ? _confirmExit : () => context.go('/'),
          ),
          bottom: running
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(kSessionHeaderHeight),
                  child: SessionProgressHeader(state: state),
                )
              : null,
        ),
        body: SafeArea(child: _body(context, state)),
      ),
    );
  }

  Widget _body(BuildContext context, SessionState state) {
    final l10n = AppLocalizations.of(context);
    if (_startError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(
                l10n.sessionStartError,
                key: const Key('session-start-error'),
                textAlign: TextAlign.center,
              ),
              FilledButton(
                key: const Key('session-retry'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
                onPressed: () => _start(extraNew: _extraNew),
                child: Text(l10n.sessionRetry),
              ),
            ],
          ),
        ),
      );
    }
    switch (state.status) {
      case SessionStatus.idle:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const CircularProgressIndicator(),
              Text(l10n.sessionLoading),
            ],
          ),
        );
      case SessionStatus.running:
        return SessionQuestionStep(
          // Новый вопрос — новое состояние ввода и оценки.
          key: ValueKey(
            '${state.startedAt?.microsecondsSinceEpoch}-${state.index}',
          ),
          item: state.current!,
          startedAt: state.startedAt!,
        );
      case SessionStatus.finished:
        final queue = state.queue!;
        if (queue.isEmpty) {
          return SessionEmptyView(
            queue: queue,
            onTakeNew: () => _start(extraNew: kTakeNewCount),
          );
        }
        return SessionSummary(state: state, onAnotherSession: _start);
    }
  }
}
