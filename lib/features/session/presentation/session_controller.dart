import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/data/sync_providers.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/uuid.dart';
import '../../reminders/presentation/reminder_controller.dart';
import '../../srs/domain/rating.dart';
import '../../srs/domain/scheduler.dart';
import '../data/session_providers.dart';
import '../domain/grade_source.dart';
import '../domain/review_log.dart';
import '../domain/session_state.dart';

/// Ведёт одну сессию: строит очередь, принимает ответы, следит за таймером
/// (ТЗ M3, §8.2). Время — только через `clockProvider`; таймер не тикает сам,
/// экран сверяет [SessionState.remaining] со своим тикером.
class SessionController extends Notifier<SessionState> {
  /// Идёт запись ответа: повторный `submit` (двойной тап) игнорируется, иначе
  /// одно знание получило бы два повторения.
  var _submitting = false;

  @override
  SessionState build() => const SessionState();

  /// Строит очередь и начинает сессию. Пустая очередь — сразу
  /// [SessionStatus.finished] (экран покажет пустое состояние по
  /// `state.queue`). [extraNew] — «Взять новые» сверх дневного лимита.
  /// [deckId] — сессия по одной колоде («Начать по этой колоде», T18);
  /// `null` — по всем скачанным.
  Future<void> start({int extraNew = 0, String? deckId}) async {
    final now = ref.read(clockProvider)();
    final queue = await ref
        .read(sessionQueueBuilderProvider)
        .build(
          now: now,
          settings: ref.read(sessionSettingsProvider).forDeck(deckId),
          extraNew: extraNew,
        );
    if (!ref.mounted) return;
    state = SessionState(
      status: queue.isEmpty ? SessionStatus.finished : SessionStatus.running,
      queue: queue,
      startedAt: now,
    );
  }

  /// Принимает ответ на текущий вопрос: считает новое состояние FSRS и
  /// пишет лог и состояние одной транзакцией. После записи — следующий
  /// вопрос, а если очередь кончилась или вышло время (начатый вопрос
  /// дописывается) — [SessionStatus.finished]. При ошибке записи
  /// (`LocalStorageError`) вопрос остаётся текущим, можно повторить.
  Future<void> submit({
    required Rating rating,
    required GradeSource gradeSource,
    required int durationMs,
    String? answerText,
    double? llmScore,
  }) async {
    final current = state.current;
    if (current == null || _submitting) return;
    _submitting = true;
    try {
      final now = ref.read(clockProvider)();
      final newState = const Scheduler()
          .review(current.state, rating, now)
          .copyWith(lastQuestionId: current.question.id);
      final log = ReviewLog(
        id: ref.read(uuidGeneratorProvider)(),
        deckId: current.item.deckId,
        deckVersion: current.deckVersion,
        itemId: current.item.id,
        questionId: current.question.id,
        questionType: current.question.type,
        rating: rating,
        gradeSource: gradeSource,
        llmScore: llmScore,
        answerText: answerText,
        durationMs: durationMs,
        reviewedAt: now,
      );
      await ref
          .read(sessionRepositoryProvider)
          .recordReview(log: log, state: newState);
      if (!ref.mounted) return;
      final next = state.index + 1;
      // Завершили вручную, пока писался ответ: остаётся finished.
      final goOn =
          state.status == SessionStatus.running &&
          next < state.queue!.items.length &&
          state.remaining(now) > Duration.zero;
      state = state.copyWith(
        status: goOn ? SessionStatus.running : SessionStatus.finished,
        index: next,
        answers: [...state.answers, log],
      );
      // Сессия закончилась этим ответом (или `finish()` во время записи:
      // тогда его прогон мог не увидеть этот ответ) — синхронизировать и
      // пересчитать напоминания.
      if (!goOn) _onSessionEnd();
    } finally {
      _submitting = false;
    }
  }

  /// Пользователь закончил сессию сам. Ответы уже записаны.
  void finish() {
    if (state.status == SessionStatus.running) {
      state = state.copyWith(status: SessionStatus.finished);
      _onSessionEnd();
    }
  }

  /// Конец сессии. Синхронизация (ТЗ §7.3): ответы уже в локальной БД,
  /// отправка идёт в фоне и сессию не задерживает; сетевых вызовов отсюда
  /// нет (CLAUDE.md, правило 4), только просьба к `SyncService`.
  /// Напоминания: `due` сдвинулись, сегодняшнее напоминание могло стать
  /// ненужным (ТЗ M9). Ничего не ждём: итоги не зависят ни от сети, ни от
  /// уведомлений.
  void _onSessionEnd() {
    ref.read(syncRequestProvider)();
    unawaited(ref.read(reminderControllerProvider.notifier).reschedule());
  }
}

final sessionControllerProvider =
    NotifierProvider.autoDispose<SessionController, SessionState>(
      SessionController.new,
    );
