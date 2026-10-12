import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/payload_parts.dart';
import '../../grading/data/grading_providers.dart';
import '../../grading/domain/grading_repository.dart';
import '../../grading/domain/llm_consent.dart';
import '../../grading/domain/open_answer_limits.dart';
import '../../grading/domain/open_grade.dart';
import '../../grading/domain/open_grader.dart';
import '../../grading/presentation/llm_consent_notifier.dart';
import '../../speech/data/speech_providers.dart';
import '../../speech/domain/speech_service.dart';
import '../../srs/domain/answer_outcome.dart';
import '../question_prompt.dart';
import '../question_result.dart';
import 'open_answer_input.dart';
import 'open_fallback.dart';
import 'open_mic_controls.dart';
import 'open_result_panel.dart';

enum _Phase {
  /// Пишем или диктуем ответ.
  input,

  /// Ждём оценку сервера.
  checking,

  /// Ответ принят: оценка сервера (или короткий ответ без запроса).
  graded,

  /// Проверки нет: эталон и самооценка.
  fallback,
}

/// Виджет `open` (ТЗ M4, M5, §4.2, §8.3): текст или диктовка, проверка
/// Edge Function `grade-open-answer`, разбор по рубрике; при сбое — эталон и
/// самооценка без блокировки сессии (AC5.2).
///
/// Состояние (текст, диктовка, идущий запрос) живёт в `State`: поворот экрана
/// и уход в фон его не теряют, а запрос не прерывается. Двойной тап по
/// «Проверить» не шлёт второй запрос (`_busy` выставляется до первого
/// `await`). `onAnswered` вызывается один раз: сразу после оценки, при
/// самооценке без повтора — сразу, при возможном повторе — по «Оценить самому».
class OpenQuestion extends ConsumerStatefulWidget {
  const OpenQuestion({
    super.key,
    required this.prompt,
    required this.questionId,
    required this.referenceAnswer,
    required this.rubric,
    required this.deckId,
    required this.deckVersion,
    required this.onAnswered,
  });

  final String prompt;
  final String questionId;
  final String referenceAnswer;
  final List<RubricPoint> rubric;
  final String deckId;
  final int deckVersion;
  final ValueChanged<QuestionResult> onAnswered;

  @override
  ConsumerState<OpenQuestion> createState() => _OpenQuestionState();
}

class _OpenQuestionState extends ConsumerState<OpenQuestion>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final SpeechService _speech;

  var _phase = _Phase.input;
  OpenGrade? _grade;
  OpenFallback? _fallback;

  /// Идёт проверка или диалог согласия: повторные тапы игнорируются.
  var _busy = false;
  var _answered = false;

  // Диктовка.
  SpeechSupport? _support;
  var _listening = false;
  SpeechFailure? _micFailure;
  StreamSubscription<SpeechUpdate>? _speechSub;
  var _speechBase = '';
  var _gotSpeech = false;

  /// Текст (хотя бы частично) надиктован: на сервер уйдёт `voice`, модель
  /// прощает ошибки распознавания. Сбрасывается, когда поле очищено.
  var _dictated = false;
  var _dictatedBeforeSession = false;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onTextChanged);
    unawaited(_loadSupport());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onTextChanged);
    unawaited(_speechSub?.cancel());
    if (_listening) unawaited(_speech.cancel());
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Микрофон не работает в фоне: закончить диктовку, текст остаётся.
    // `inactive` не трогаем: на нём живёт системный диалог разрешения на
    // микрофон, который сам запускается диктовкой.
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _listening) {
      unawaited(_finishDictation(keepText: true));
    }
  }

  void _onTextChanged() {
    if (_controller.text.isEmpty && _dictated) _dictated = false;
  }

  Future<void> _loadSupport() async {
    SpeechSupport support;
    try {
      support = await _speech.support();
    } on Object {
      support = SpeechSupport.unsupported;
    }
    if (mounted) setState(() => _support = support);
  }

  // --- Проверка -----------------------------------------------------------

  Future<void> _check() async {
    final text = _controller.text;
    if (_busy || _answered || text.trim().isEmpty) return;
    if (_phase != _Phase.input && _phase != _Phase.fallback) return;
    _busy = true;
    try {
      if (_listening) await _finishDictation(keepText: true);
      if (!mounted) return;
      if (isTooShortOpenAnswer(text)) {
        // Правило сервера (§4.2, п. 1) без запроса и без согласия.
        setState(() => _phase = _Phase.graded);
        _answer(kTooShortOpenResult);
        return;
      }
      final consent = await _ensureConsent();
      if (!mounted || consent == null) return;
      if (consent != LlmConsent.granted) {
        _toFallback(const OpenFallback(OpenFallbackReason.disabled));
        return;
      }
      setState(() => _phase = _Phase.checking);
      try {
        final grade = await ref
            .read(gradingRepositoryProvider)
            .grade(
              GradeRequest(
                deckId: widget.deckId,
                deckVersion: widget.deckVersion,
                questionId: widget.questionId,
                answerText: text,
                inputMode: _dictated
                    ? AnswerInputMode.voice
                    : AnswerInputMode.text,
              ),
            );
        if (!mounted) return;
        final result = gradeOpenAnswer(grade);
        if (result.outcome == AnswerOutcome.llmUnavailable) {
          _toFallback(const OpenFallback(OpenFallbackReason.unsure));
          return;
        }
        setState(() {
          _grade = grade;
          _phase = _Phase.graded;
        });
        _answer(result);
      } on AppError catch (e) {
        if (mounted) _toFallback(fallbackFor(e));
      }
    } finally {
      _busy = false;
    }
  }

  /// `null` — диалог закрыт без выбора, проверка не начата.
  Future<LlmConsent?> _ensureConsent() async {
    var consent = LlmConsent.unknown;
    try {
      consent = await ref.read(llmConsentProvider.future);
    } on Object {
      // Не прочитали согласие: спросим (ответ без согласия не уходит).
    }
    if (consent != LlmConsent.unknown) return consent;
    if (!mounted) return null;
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ConsentDialog(),
    );
    if (allow == null) return null;
    consent = allow ? LlmConsent.granted : LlmConsent.declined;
    try {
      await ref.read(llmConsentProvider.notifier).set(consent);
    } on AppError {
      // Не сохранилось: на этот ответ выбор действует, потом спросим снова.
    }
    return consent;
  }

  void _skip() {
    if (_busy || _answered || _phase != _Phase.input) return;
    unawaited(_finishDictation(keepText: true));
    _toFallback(const OpenFallback(OpenFallbackReason.skipped));
  }

  void _toFallback(OpenFallback fallback) {
    setState(() {
      _fallback = fallback;
      _phase = _Phase.fallback;
    });
    if (!fallback.retryable) _answer(kSelfAssessedOpenResult);
  }

  void _selfAssess() {
    if (_answered) return;
    _answer(kSelfAssessedOpenResult);
    setState(() {});
  }

  void _answer(OpenGradeResult result) {
    if (_answered) return;
    _answered = true;
    final text = _controller.text;
    widget.onAnswered(
      QuestionResult(
        outcome: result.outcome,
        answerText: text.trim().isEmpty ? null : text,
        llmScore: result.llmScore,
      ),
    );
  }

  // --- Диктовка -----------------------------------------------------------

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (_phase != _Phase.input || _busy) return;
    _speechBase = _controller.text;
    _dictatedBeforeSession = _dictated;
    _gotSpeech = false;
    // `_listening` до первого `await`: двойной тап не откроет две сессии.
    setState(() {
      _listening = true;
      _micFailure = null;
    });
    var lang = 'ru';
    try {
      lang = await ref.read(deckLangProvider(widget.deckId).future);
    } on Object {
      // Язык колоды неизвестен: русский (ТЗ, `ru_RU`).
    }
    if (!mounted || !_listening) return;
    unawaited(_speechSub?.cancel());
    _speechSub = _speech
        .listen(lang: lang)
        .listen(_onSpeech, onError: _onSpeechError, onDone: _onSpeechDone);
  }

  void _onSpeech(SpeechUpdate update) {
    if (!mounted) return;
    final spoken = update.text.trim();
    if (spoken.isNotEmpty) {
      _gotSpeech = true;
      _dictated = true;
    }
    final base = _speechBase.trimRight();
    final joined = base.isEmpty
        ? spoken
        : (spoken.isEmpty ? _speechBase : '$base $spoken');
    final text = clampOpenAnswer(joined);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onSpeechError(Object error) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      _micFailure = error is SpeechException
          ? error.failure
          : SpeechFailure.other;
      if (_micFailure == SpeechFailure.unsupported) {
        _support = SpeechSupport.unsupported;
      }
    });
  }

  void _onSpeechDone() {
    if (!mounted || !_listening) return;
    setState(() {
      _listening = false;
      // Сессия кончилась без единого слова: тишина или таймаут.
      if (!_gotSpeech) _micFailure = SpeechFailure.noSpeech;
    });
  }

  /// Закончить диктовку. [keepText] `false` — «Отмена»: вернуть текст,
  /// который был до неё.
  Future<void> _finishDictation({required bool keepText}) async {
    final sub = _speechSub;
    _speechSub = null;
    unawaited(sub?.cancel());
    await _speech.cancel();
    if (!mounted) return;
    if (!keepText) {
      _controller.value = TextEditingValue(
        text: _speechBase,
        selection: TextSelection.collapsed(offset: _speechBase.length),
      );
      _dictated = _dictatedBeforeSession;
    }
    setState(() {
      _listening = false;
      _micFailure = null;
    });
  }

  // --- Вид ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final editable = _phase == _Phase.input;
    final fallback = _fallback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionPrompt(widget.prompt),
        const SizedBox(height: 16),
        OpenAnswerInput(
          controller: _controller,
          focusNode: _focus,
          readOnly: !editable || _listening,
        ),
        const SizedBox(height: 8),
        if (editable || _listening)
          OpenMicControls(
            support: _support,
            listening: _listening,
            failure: _micFailure,
            enabled: editable && !_busy,
            dictated: _dictated,
            canOpenSettings: ref.read(appSettingsOpenerProvider).isSupported,
            onToggle: _toggleDictation,
            onCancel: () => _finishDictation(keepText: false),
            onOpenSettings: ref.read(appSettingsOpenerProvider).openAppSettings,
          ),
        if (editable) ...[
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => Row(
              spacing: 8,
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('open-check'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 56),
                    ),
                    onPressed: value.text.trim().isEmpty ? null : _check,
                    child: Text(l10n.openCheck),
                  ),
                ),
                OutlinedButton(
                  key: const Key('open-skip'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: _skip,
                  child: Text(l10n.openDontRemember),
                ),
              ],
            ),
          ),
        ],
        if (_phase == _Phase.checking) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Row(
              key: const Key('open-checking'),
              spacing: 12,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                Text(l10n.openChecking, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
        if (_phase == _Phase.graded) ...[
          const SizedBox(height: 16),
          OpenResultPanel(
            grade: _grade,
            rubric: widget.rubric,
            referenceAnswer: widget.referenceAnswer,
          ),
        ],
        if (_phase == _Phase.fallback && fallback != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              openFallbackText(l10n, fallback),
              key: const Key('open-fallback-message'),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 12),
          OpenResultPanel(
            grade: null,
            rubric: widget.rubric,
            referenceAnswer: widget.referenceAnswer,
          ),
          if (!_answered) ...[
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: [
                if (fallback.retryable)
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('open-retry'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 56),
                      ),
                      onPressed: _busy ? null : _check,
                      child: Text(l10n.openCheckAgain),
                    ),
                  ),
                Expanded(
                  child: FilledButton(
                    key: const Key('open-self-assess'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 56),
                    ),
                    onPressed: _selfAssess,
                    child: Text(l10n.openSelfAssess),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.openConsentTitle),
      content: SingleChildScrollView(child: Text(l10n.openConsentBody)),
      actions: [
        TextButton(
          key: const Key('open-consent-decline'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.openConsentDecline),
        ),
        FilledButton(
          key: const Key('open-consent-allow'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.openConsentAllow),
        ),
      ],
    );
  }
}
