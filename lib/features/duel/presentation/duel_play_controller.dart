import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/clock.dart';
import '../../questions/question_result.dart';
import '../../questions/registry.dart';
import '../../srs/domain/answer_outcome.dart';
import '../data/duel_providers.dart';
import '../domain/duel.dart';
import '../domain/duel_answer.dart';
import '../domain/duel_answer_validator.dart';
import '../domain/duel_content.dart';
import '../domain/duel_status.dart';

/// Где находится прохождение дуэли.
enum DuelPlayPhase {
  /// Читаем дуэль, колоду и свои уже данные ответы.
  loading,

  /// Не удалось прочитать дуэль (сеть и т. п.): [DuelPlayState.error].
  error,

  /// Дуэли нет или она чужая.
  notFound,

  /// Дуэль закрыта для ответов: срок вышел или она завершена.
  closed,

  /// Колоды нет на устройстве или в ней нет части вопросов набора: играть
  /// нельзя, пока колоду не обновят, либо пока пользователь не согласится
  /// сыграть без них (ADR-36).
  blocked,

  /// Идёт игра: на экране вопрос [DuelPlayState.index].
  playing,

  /// На все вопросы отвечено (ответы лежат в очереди или уже на сервере).
  done,
}

/// Состояние прохождения дуэли.
class DuelPlayState {
  const DuelPlayState({
    this.phase = DuelPlayPhase.loading,
    this.duel,
    this.slots = const [],
    this.answered = const {},
    this.index = 0,
    this.shownAt,
    this.currentAnswered = false,
    this.lastDurationMs = 0,
    this.saveFailed = false,
    this.deckMissing = false,
    this.error,
  });

  final DuelPlayPhase phase;
  final Duel? duel;

  /// Вопросы набора в порядке набора.
  final List<DuelSlot> slots;

  /// Вопросы, на которые уже отвечено: на сервере или в очереди отправки.
  final Set<String> answered;

  /// Номер текущего вопроса в [slots].
  final int index;

  /// Когда текущий вопрос появился на экране (UTC); секундомер идёт от него.
  final DateTime? shownAt;

  /// Ответ на текущий вопрос принят и записан; ждём «Дальше».
  final bool currentAnswered;

  /// Время ответа на текущий вопрос (для замороженного секундомера).
  final int lastDurationMs;

  /// Ответ не удалось сохранить локально: можно повторить.
  final bool saveFailed;

  /// Колоды дуэли нет на устройстве.
  final bool deckMissing;
  final AppError? error;

  DuelSlot? get current => phase == DuelPlayPhase.playing ? slots[index] : null;

  /// Вопросы, которых нельзя показать на этом устройстве, из ещё не
  /// отвеченных.
  int get unavailableCount => [
    for (final s in slots)
      if (!s.isPlayable && !answered.contains(s.questionId)) s,
  ].length;

  DuelPlayState copyWith({
    DuelPlayPhase? phase,
    Duel? duel,
    List<DuelSlot>? slots,
    Set<String>? answered,
    int? index,
    DateTime? shownAt,
    bool? currentAnswered,
    int? lastDurationMs,
    bool? saveFailed,
    bool? deckMissing,
    AppError? error,
  }) => DuelPlayState(
    phase: phase ?? this.phase,
    duel: duel ?? this.duel,
    slots: slots ?? this.slots,
    answered: answered ?? this.answered,
    index: index ?? this.index,
    shownAt: shownAt ?? this.shownAt,
    currentAnswered: currentAnswered ?? this.currentAnswered,
    lastDurationMs: lastDurationMs ?? this.lastDurationMs,
    saveFailed: saveFailed ?? this.saveFailed,
    deckMissing: deckMissing ?? this.deckMissing,
    error: error ?? this.error,
  );
}

/// Прохождение дуэли (ТЗ M10, §8.4, ADR-16, ADR-36): те же виджеты вопросов из
/// реестра, без панели оценки; ответ пишется только в очередь отправки
/// (`DuelAnswerQueue`, outbox `duel_answer`), в `review_logs`,
/// `user_item_state` и FSRS не попадает. Время — через `clockProvider`;
/// секундомер вопроса считается от [DuelPlayState.shownAt], без лимита (§8.4).
///
/// Повторный ответ невозможен: ещё до показа вопросов собирается набор уже
/// отвеченных (сервер + очередь), игра идёт с первого неотвеченного; повтор
/// внутри сессии игнорируется ([_busy], `currentAnswered`), а очередь не
/// принимает второй ответ на тот же вопрос.
class DuelPlayController extends Notifier<DuelPlayState> {
  DuelPlayController(this.duelId);

  final String duelId;

  /// Идёт запись ответа (двойной тап).
  var _busy = false;

  /// Ответ, который не удалось сохранить: для повтора.
  DuelAnswerPayload? _unsaved;

  @override
  DuelPlayState build() => const DuelPlayState();

  /// Читает дуэль и готовит игру. Не бросает: итог в [DuelPlayState.phase].
  Future<void> load() async {
    state = const DuelPlayState();
    try {
      final duel = await ref.read(duelRepositoryProvider).get(duelId);
      if (!ref.mounted) return;
      if (duel == null) {
        state = state.copyWith(phase: DuelPlayPhase.notFound);
        return;
      }
      final now = ref.read(clockProvider)();
      final status = duel.statusAt(now);
      if (status != DuelStatus.open && status != DuelStatus.active) {
        state = state.copyWith(phase: DuelPlayPhase.closed, duel: duel);
        return;
      }
      final content = await ref
          .read(duelContentSourceProvider)
          .load(duel.deckId, duel.questionIds);
      if (!ref.mounted) return;
      if (content == null) {
        state = state.copyWith(
          phase: DuelPlayPhase.blocked,
          duel: duel,
          deckMissing: true,
        );
        return;
      }
      final slots = resolveDuelSlots(
        duel.questionIds,
        content,
        supportedTypes: ref.read(supportedQuestionTypesProvider),
      );
      final answered = await _answeredIds(duel);
      if (!ref.mounted) return;
      state = state.copyWith(duel: duel, slots: slots, answered: answered);
      _advance(from: 0);
    } on AppError catch (e) {
      if (ref.mounted) {
        state = state.copyWith(phase: DuelPlayPhase.error, error: e);
      }
    }
  }

  /// Уже данные ответы: на сервере и в очереди отправки. Нет сети — только
  /// очередь (сервер всё равно не примет второй ответ на тот же вопрос).
  Future<Set<String>> _answeredIds(Duel duel) async {
    final pending = await ref
        .read(duelAnswerQueueProvider)
        .pendingQuestionIds(duelId);
    if (duel.myDoneAt != null) return {...duel.questionIds};
    try {
      final server = await ref.read(duelRepositoryProvider).answers(duelId);
      return {...pending, for (final a in server.mine) a.questionId};
    } on NetworkError {
      return pending;
    }
  }

  /// Переходит к первому неотвеченному вопросу не раньше [from]; если таких
  /// нет — к концу игры; если он недоступен — к блокировке.
  void _advance({required int from}) {
    final slots = state.slots;
    var i = from;
    while (i < slots.length && state.answered.contains(slots[i].questionId)) {
      i++;
    }
    if (i >= slots.length) {
      state = state.copyWith(phase: DuelPlayPhase.done);
      return;
    }
    if (state.unavailableCount > 0) {
      state = state.copyWith(phase: DuelPlayPhase.blocked);
      return;
    }
    state = state.copyWith(
      phase: DuelPlayPhase.playing,
      index: i,
      shownAt: ref.read(clockProvider)(),
      currentAnswered: false,
      lastDurationMs: 0,
      saveFailed: false,
    );
  }

  /// «Сыграть без них»: недоступные вопросы засчитываются неверными (ответ
  /// `{"skipped": true}`, время 0), остальные играются как обычно (ADR-36).
  Future<void> playWithoutUnavailable() async {
    // Колоды нет: недоступно всё, пропускать нечего (сперва докачка).
    if (state.phase != DuelPlayPhase.blocked || state.deckMissing || _busy) {
      return;
    }
    _busy = true;
    try {
      final queue = ref.read(duelAnswerQueueProvider);
      final answered = {...state.answered};
      for (final s in state.slots) {
        if (s.isPlayable || answered.contains(s.questionId)) continue;
        await queue.enqueue(
          DuelAnswerPayload.skipped(duelId: duelId, questionId: s.questionId),
        );
        answered.add(s.questionId);
      }
      if (!ref.mounted) return;
      state = state.copyWith(answered: answered);
      _advance(from: 0);
    } on AppError catch (e) {
      if (ref.mounted) state = state.copyWith(error: e, saveFailed: true);
    } finally {
      _busy = false;
    }
  }

  /// Ответ на текущий вопрос принят виджетом формата: пишется в очередь
  /// отправки. Повторный вызов на тот же вопрос игнорируется.
  Future<void> onAnswered(QuestionResult result) async {
    final slot = state.current;
    final shownAt = state.shownAt;
    if (slot == null ||
        shownAt == null ||
        state.currentAnswered ||
        _busy ||
        state.answered.contains(slot.questionId)) {
      return;
    }
    final elapsed = ref
        .read(clockProvider)()
        .difference(shownAt)
        .inMilliseconds;
    final durationMs = elapsed.clamp(0, kDuelMaxDurationMs);
    _unsaved = DuelAnswerPayload(
      duelId: duelId,
      questionId: slot.questionId,
      answer: result.answer ?? const {},
      isCorrect: result.outcome == AnswerOutcome.autoCorrect,
      durationMs: durationMs,
    );
    state = state.copyWith(lastDurationMs: durationMs);
    await _save();
  }

  /// Повторяет сохранение, если оно не удалось.
  Future<void> retrySave() => _save();

  Future<void> _save() async {
    var payload = _unsaved;
    if (payload == null || _busy) return;
    // Ответ, который сервер не примёт, в очередь не идёт (иначе вопрос навсегда
    // остался бы неотвеченным): вместо него засчитывается пропуск.
    if (!isValidDuelAnswerPayload(payload)) {
      payload = DuelAnswerPayload.skipped(
        duelId: duelId,
        questionId: payload.questionId,
      );
      _unsaved = payload;
    }
    _busy = true;
    try {
      // `false` — такой ответ уже стоит в очереди: для игры это то же самое.
      await ref.read(duelAnswerQueueProvider).enqueue(payload);
      if (!ref.mounted) return;
      _unsaved = null;
      state = state.copyWith(
        answered: {...state.answered, payload.questionId},
        currentAnswered: true,
        saveFailed: false,
      );
    } on InvalidDuelAnswerError catch (e) {
      // Повтор не поможет: вопрос закрывается локально, ошибка остаётся в
      // состоянии.
      _unsaved = null;
      if (ref.mounted) {
        state = state.copyWith(
          answered: {...state.answered, payload.questionId},
          currentAnswered: true,
          saveFailed: false,
          error: e,
        );
      }
    } on AppError {
      if (ref.mounted) state = state.copyWith(saveFailed: true);
    } finally {
      _busy = false;
    }
  }

  /// «Дальше» после ответа: следующий неотвеченный вопрос или конец игры.
  void next() {
    if (state.phase != DuelPlayPhase.playing || !state.currentAnswered) return;
    _advance(from: state.index + 1);
  }
}

final duelPlayProvider = NotifierProvider.autoDispose
    .family<DuelPlayController, DuelPlayState, String>(DuelPlayController.new);
