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

/// Всё остальное, чего мы не ожидали.
final class UnexpectedError extends AppError {
  const UnexpectedError(super.message, {super.cause});
}
