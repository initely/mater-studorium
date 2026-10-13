/// Типизированные ошибки, которые репозитории отдают наверх вместо сырых
/// исключений Supabase и drift (CLAUDE.md, «Соглашения»).
sealed class AppError implements Exception {
  const AppError(this.message, {this.cause});

  /// Техническое описание для логов, не для показа пользователю.
  final String message;

  /// Исходное исключение, если оно есть.
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// Нет сети или сервер временно недоступен: операцию можно повторить позже.
final class NetworkError extends AppError {
  const NetworkError(super.message, {super.cause});
}

/// Сервер отклонил запрос авторизации (например, anonymous sign-ins выключены).
/// Повтор сам по себе не поможет.
final class AuthError extends AppError {
  const AuthError(super.message, {super.cause});
}

/// Вход через провайдера (Google, T21) не настроен на сервере: провайдер
/// выключен или не включено ручное связывание (`manual_linking_disabled`,
/// `validation_failed`). Повтор не поможет, пока не заданы ключи (README,
/// «Привязка Google»).
final class ProviderUnavailableError extends AppError {
  const ProviderUnavailableError(super.message, {super.cause});
}

/// Знание с таким `id` уже принадлежит другой колоде (ADR-21: `item_id`
/// глобально уникален). Колоду записывать нельзя: прогресс по знанию
/// перепутался бы между колодами.
final class ItemIdCollisionError extends AppError {
  const ItemIdCollisionError(this.itemId, this.otherDeckId)
    : super('item_id $itemId уже принадлежит колоде $otherDeckId');

  final String itemId;
  final String otherDeckId;
}

/// Вопрос с таким `id` уже принадлежит знанию другой колоды. Как и `item_id`,
/// id вопроса глобально уникален (PK `questions.id`): запись перезаписала бы
/// чужой вопрос. Колоду записывать нельзя.
final class QuestionIdCollisionError extends AppError {
  const QuestionIdCollisionError(this.questionId, this.otherDeckId)
    : super('question_id $questionId уже принадлежит колоде $otherDeckId');

  final String questionId;
  final String otherDeckId;
}

/// Файл колоды не разбирается или нарушает правила формата (ТЗ M2, AC2.3).
/// Ничего не записано, прежняя версия колоды остаётся на месте.
final class DeckFormatError extends AppError {
  const DeckFormatError(super.message, {super.cause});
}

/// `schema_version` колоды выше поддерживаемой клиентом: нужно обновить
/// приложение (ADR-19). Прежняя версия колоды остаётся на месте.
final class DeckSchemaTooNewError extends AppError {
  const DeckSchemaTooNewError(this.schemaVersion, this.supportedVersion)
    : super(
        'schema_version колоды $schemaVersion, клиент понимает до '
        '$supportedVersion',
      );

  final int schemaVersion;
  final int supportedVersion;
}

/// Колоды нет в каталоге сервера (или она недоступна этому пользователю).
final class DeckNotFoundError extends AppError {
  const DeckNotFoundError(this.deckId) : super('колода $deckId не найдена');

  final String deckId;
}

/// Локальная БД отказала при записи или чтении прогресса (диск, ограничение
/// уникальности и т. п.). Транзакция откатена, ничего не записано.
final class LocalStorageError extends AppError {
  const LocalStorageError(super.message, {super.cause});
}

/// Сервер отклонил пакет синхронизации как неверный (значение вне диапазона,
/// не тот тип, превышен размер пакета). Пакет атомарен: ничего не записано.
/// Повтор того же пакета не поможет; клиент такие строки не отправляет
/// (`sync_validator.dart`), так что это признак расхождения правил клиента и
/// сервера.
final class SyncRejectedError extends AppError {
  const SyncRejectedError(super.message, {super.cause});
}

/// Дневной лимит оценки открытых ответов исчерпан (429: `quota_exceeded`,
/// `request_limit`, `budget_exceeded`, ТЗ §5.5). Повтор до [resetAt] не
/// поможет: ответ оценивает сам пользователь.
final class QuotaExceededError extends AppError {
  const QuotaExceededError(super.message, {this.resetAt, super.cause});

  /// Когда лимит обнулится (UTC), если сервер это сообщил.
  final DateTime? resetAt;
}

/// Сервер не принял запрос как неверный (400, 403, 404, 413: ошибка ввода или
/// расхождение клиента и сервера, ADR-31). Тот же запрос не пройдёт, поэтому
/// повтор не предлагается.
final class RequestRejectedError extends AppError {
  const RequestRejectedError(super.message, {this.status, this.code});

  /// HTTP-статус ответа, если запрос дошёл до сервера.
  final int? status;

  /// `error.code` из тела ответа, если он разобран.
  final String? code;
}

/// Кода дуэли нет или дуэль просрочена (AC10.2). Сервер отвечает одинаково на
/// оба случая (ADR-35): оракула «код был, но истёк» нет.
final class DuelCodeNotFoundError extends AppError {
  const DuelCodeNotFoundError() : super('код дуэли не найден или просрочен');
}

/// В дуэли уже два участника (код существует, но места нет).
final class DuelFullError extends AppError {
  const DuelFullError() : super('в дуэли уже есть соперник');
}

/// Какой лимит дуэлей сработал (`MS429`, `hint` в 0007_duels.sql).
enum DuelLimitKind {
  /// Слишком много активных дуэлей (создатель: 5, участник: 10).
  activeDuels,

  /// Больше 20 созданных дуэлей за UTC-сутки.
  dailyCreate,

  /// Слишком много неудачных попыток войти по коду (10 в час на человека
  /// или 1000 в час на всех).
  joinAttempts,
}

/// Лимит дуэлей исчерпан: повтор сразу не поможет.
final class DuelLimitError extends AppError {
  const DuelLimitError(this.kind, {super.cause})
    : super('лимит дуэлей исчерпан');

  final DuelLimitKind kind;
}

/// Дуэль закрыта для ответов: срок вышел, она завершена или такой дуэли нет
/// у этого пользователя (`MS410`, `MS404` из `submit_duel_answer`). Повтор не
/// поможет: запись из outbox отбрасывается.
final class DuelClosedError extends AppError {
  const DuelClosedError(super.message, {super.cause});
}

/// Ответ дуэли не проходит ограничения сервера (форма, размер до 512 байт,
/// время): в очередь отправки он не ставится, иначе блокировал бы её. Ничего не
/// записано.
final class InvalidDuelAnswerError extends AppError {
  const InvalidDuelAnswerError(super.message, {super.cause});
}

/// В колоде меньше пяти подходящих (автопроверяемых, видимых) вопросов:
/// дуэль не собрать. Ошибка клиентская, сервер не вызывался.
final class DuelNotEnoughQuestionsError extends AppError {
  const DuelNotEnoughQuestionsError(this.available)
    : super('для дуэли нужно 5 вопросов, в колоде $available');

  final int available;
}

/// Всё остальное, чего мы не ожидали.
final class UnexpectedError extends AppError {
  const UnexpectedError(super.message, {super.cause});
}
