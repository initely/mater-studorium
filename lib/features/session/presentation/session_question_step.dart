import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/stable_seed.dart';
import '../../explanations/domain/explanation.dart';
import '../../explanations/presentation/explanation_panel.dart';
import '../../questions/question_request.dart';
import '../../questions/question_result.dart';
import '../../questions/registry.dart';
import '../../srs/domain/rating.dart';
import '../../srs/domain/rating_suggester.dart';
import '../domain/session_item.dart';
import 'rating_bar.dart';
import 'session_controller.dart';
import 'verdict_banner.dart';

/// Один вопрос сессии: виджет формата из реестра, после ответа — вердикт и
/// панель оценки, запись через `SessionController.submit` (ТЗ §8.2, п. 2–4).
///
/// Знает только про `QuestionResult` и `AnswerOutcome`, не про форматы:
/// новый формат добавляется в реестр, а этот файл не меняется. Экран
/// создаёт его с ключом по номеру вопроса, поэтому состояние (ответ,
/// оценка, ошибка) живёт, пока вопрос на экране, и переживает поворот.
class SessionQuestionStep extends ConsumerStatefulWidget {
  const SessionQuestionStep({
    super.key,
    required this.item,
    required this.startedAt,
  });

  final SessionItem item;

  /// Старт сессии: дата входит в зерно перемешивания (ТЗ M4).
  final DateTime startedAt;

  @override
  ConsumerState<SessionQuestionStep> createState() =>
      _SessionQuestionStepState();
}

class _SessionQuestionStepState extends ConsumerState<SessionQuestionStep> {
  /// Когда вопрос появился (для `duration_ms`); задаётся в `initState`,
  /// а не лениво: иначе отсчёт начался бы при первом ответе.
  late final DateTime _shownAt;
  late final int _shuffleSeed = stableSeed(
    '${widget.item.question.id}|${_dateKey(widget.startedAt)}',
  );
  final _panelKey = GlobalKey();

  QuestionResult? _result;
  int _durationMs = 0;
  var _saving = false;
  var _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _shownAt = ref.read(clockProvider)();
  }

  static String _dateKey(DateTime utc) {
    final d = utc.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  void _onAnswered(QuestionResult result) {
    if (_result != null) return;
    final elapsed = ref.read(clockProvider)().difference(_shownAt);
    setState(() {
      _result = result;
      _durationMs = elapsed.isNegative ? 0 : elapsed.inMilliseconds;
    });
    // Панель оценки может оказаться ниже экрана.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final panel = _panelKey.currentContext;
      if (panel != null && mounted) {
        Scrollable.ensureVisible(
          panel,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  Future<void> _rate(Rating rating) async {
    final result = _result;
    if (result == null || _saving) return;
    final suggestion = suggestRating(result.outcome);
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .submit(
            rating: rating,
            gradeSource: suggestion.sourceFor(rating),
            durationMs: _durationMs,
            answerText: result.answerText,
            llmScore: result.llmScore,
          );
    } on AppError {
      // Вопрос остался текущим (SessionController), можно оценить ещё раз.
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final question = widget.item.question;
    final module = ref.watch(questionRegistryProvider).moduleFor(question.type);
    final result = _result;

    if (module == null) {
      // Очередь берёт только поддерживаемые форматы, это запасной выход.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              l10n.sessionUnsupported,
              key: const Key('session-unsupported'),
            ),
            FilledButton(
              onPressed: ref.read(sessionControllerProvider.notifier).finish,
              child: Text(l10n.sessionFinishNow),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              module.build(
                context,
                QuestionRequest(
                  question: question,
                  shuffleSeed: _shuffleSeed,
                  onAnswered: _onAnswered,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 16),
                VerdictBanner(outcome: result.outcome),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: _panelKey,
                  child: RatingBar(
                    suggestion: suggestRating(result.outcome),
                    enabled: !_saving,
                    onRate: _rate,
                  ),
                ),
                if (_saveFailed) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.sessionSaveError,
                      key: const Key('session-save-error'),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
                // Разбор по желанию (ТЗ §8.2, п. 3, M6) ниже панели оценки:
                // не блокирует ни оценку, ни «Дальше» (AC6.1).
                // T20: рядом с ним — ⚑ «Пожаловаться».
                const SizedBox(height: 16),
                ExplanationPanel(
                  explanation: Explanation.of(widget.item.item, question),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
