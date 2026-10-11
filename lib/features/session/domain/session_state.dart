import 'review_log.dart';
import 'session_item.dart';
import 'session_queue.dart';

/// Длительность сессии (ТЗ M3: «5 мин»).
const Duration kSessionDuration = Duration(minutes: 5);

enum SessionStatus {
  /// Сессия не начата.
  idle,

  /// Идёт: [SessionState.current] — вопрос на экране.
  running,

  /// Закончилась: очередь пуста (в том числе изначально), вышло время и
  /// последний вопрос дописан, или пользователь завершил её сам.
  finished,
}

/// Состояние сессии для экрана (T13) и итогов (T14).
class SessionState {
  const SessionState({
    this.status = SessionStatus.idle,
    this.queue,
    this.index = 0,
    this.startedAt,
    this.answers = const [],
  });

  final SessionStatus status;

  /// Очередь, построенная при старте; `null` в [SessionStatus.idle].
  final SessionQueue? queue;

  /// Номер текущего вопроса в `queue.items`.
  final int index;

  /// Момент старта (UTC); таймер отсчитывается от него.
  final DateTime? startedAt;

  /// Ответы этой сессии в порядке ответа (для итогов).
  final List<ReviewLog> answers;

  /// Когда истекает таймер; `null` до старта.
  DateTime? get deadline => startedAt?.add(kSessionDuration);

  /// Текущий вопрос; `null` вне [SessionStatus.running].
  SessionItem? get current =>
      status == SessionStatus.running ? queue!.items[index] : null;

  /// Сколько осталось по таймеру на момент [now] (не меньше нуля); до старта —
  /// вся длительность.
  Duration remaining(DateTime now) {
    final end = deadline;
    if (end == null) return kSessionDuration;
    final left = end.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  SessionState copyWith({
    SessionStatus? status,
    int? index,
    List<ReviewLog>? answers,
  }) => SessionState(
    status: status ?? this.status,
    queue: queue,
    index: index ?? this.index,
    startedAt: startedAt,
    answers: answers ?? this.answers,
  );
}
