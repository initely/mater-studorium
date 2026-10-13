/// Ключ в `answer` для `mcq`: id выбранных вариантов.
const kDuelAnswerSelectedKey = 'selected';

/// Ключи в `answer` форматов MVP-b: тексты в пропусках `cloze` (id → текст),
/// id шагов `order` в порядке игрока, номера выбранных строк `find_error`.
const kDuelAnswerClozeKey = 'answers';
const kDuelAnswerOrderKey = 'order';
const kDuelAnswerLinesKey = 'lines';

/// Ключ в `answer`, когда ответ не поместился в предел размера и заменён
/// пометкой (форма ответа неизвестна, верность и время сохранены).
const kDuelAnswerOmittedKey = 'omitted';

/// Ключ в `answer`, когда вопрос не показан и засчитан неверным («Сыграть без
/// недоступных», ADR-36).
const kDuelAnswerSkippedKey = 'skipped';

/// Ответ участника на один вопрос дуэли: тело RPC `submit_duel_answer` и
/// содержимое записи outbox (`kind = duel_answer`). Идемпотентность держит
/// сервер по ключу (дуэль, пользователь, вопрос): повтор безвреден.
class DuelAnswerPayload {
  const DuelAnswerPayload({
    required this.duelId,
    required this.questionId,
    required this.answer,
    required this.isCorrect,
    required this.durationMs,
  });

  /// Ответ-пропуск: вопрос недоступен на устройстве, засчитан неверным.
  factory DuelAnswerPayload.skipped({
    required String duelId,
    required String questionId,
  }) => DuelAnswerPayload(
    duelId: duelId,
    questionId: questionId,
    answer: const {kDuelAnswerSkippedKey: true},
    isCorrect: false,
    durationMs: 0,
  );

  final String duelId;
  final String questionId;

  /// JSON-объект (CHECK сервера: object или array, до 512 байт).
  final Map<String, Object?> answer;

  /// Верно ли, по локальной проверке: сервер верного ответа не знает
  /// (ADR-35, п. 2).
  final bool isCorrect;
  final int durationMs;

  Map<String, Object?> toJson() => {
    'duel_id': duelId,
    'question_id': questionId,
    'answer': answer,
    'is_correct': isCorrect,
    'duration_ms': durationMs,
  };

  /// Разбор записи outbox; `null`, если форма не та (такая запись
  /// «ядовитая» и отбрасывается).
  static DuelAnswerPayload? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final duelId = json['duel_id'];
    final questionId = json['question_id'];
    final answer = json['answer'];
    final isCorrect = json['is_correct'];
    final durationMs = json['duration_ms'];
    if (duelId is! String ||
        questionId is! String ||
        answer is! Map<String, dynamic> ||
        isCorrect is! bool ||
        durationMs is! int) {
      return null;
    }
    return DuelAnswerPayload(
      duelId: duelId,
      questionId: questionId,
      answer: answer,
      isCorrect: isCorrect,
      durationMs: durationMs,
    );
  }
}

/// Ответ, который сервер хранит (строка `duel_answers`): для экрана
/// результата.
class DuelAnswerRecord {
  const DuelAnswerRecord({
    required this.questionId,
    required this.answer,
    required this.isCorrect,
    required this.durationMs,
  });

  final String questionId;

  /// Как прислал клиент; форма неизвестна (с другого клиента могла быть иной).
  final Object? answer;
  final bool isCorrect;
  final int durationMs;

  /// Выбранные варианты `mcq`; пусто, если ответа нет в ожидаемой форме.
  List<String> get selectedOptionIds {
    final a = answer;
    if (a is! Map) return const [];
    final selected = a[kDuelAnswerSelectedKey];
    if (selected is! List) return const [];
    return [
      for (final id in selected)
        if (id is String) id,
    ];
  }

  /// Тексты в пропусках `cloze` по id пропуска; пусто, если формы нет.
  Map<String, String> get clozeAnswers {
    final a = answer;
    if (a is! Map) return const {};
    final map = a[kDuelAnswerClozeKey];
    if (map is! Map) return const {};
    return {
      for (final e in map.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  }

  /// Порядок шагов `order` (id); пусто, если формы нет.
  List<String> get orderedStepIds {
    final a = answer;
    if (a is! Map) return const [];
    final ids = a[kDuelAnswerOrderKey];
    if (ids is! List) return const [];
    return [
      for (final id in ids)
        if (id is String) id,
    ];
  }

  /// Выбранные строки `find_error`; пусто, если формы нет.
  List<int> get selectedLines {
    final a = answer;
    if (a is! Map) return const [];
    final lines = a[kDuelAnswerLinesKey];
    if (lines is! List) return const [];
    return [
      for (final n in lines)
        if (n is int) n,
    ];
  }

  /// Вопрос не был показан: засчитан неверным.
  bool get wasSkipped {
    final a = answer;
    return a is Map && a[kDuelAnswerSkippedKey] == true;
  }
}

/// Ответы обоих участников. [other] пуст, пока клиент их не запрашивал
/// (дуэль не завершена, AC10.1).
class DuelAnswers {
  const DuelAnswers({required this.mine, required this.other});

  final List<DuelAnswerRecord> mine;
  final List<DuelAnswerRecord> other;
}
