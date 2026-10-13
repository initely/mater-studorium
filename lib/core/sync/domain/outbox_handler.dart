import '../outbox_entry.dart';

/// Отправляет одну запись outbox на сервер от имени [userId] (шаг 3 §7.3).
/// Должен быть идемпотентным: если ответ сервера потерялся, запись уйдёт
/// снова. Ошибки — `AppError`: `NetworkError` и `AuthError` останавливают
/// прогон (запись останется), остальные увеличивают `attempts` записи, и
/// прогон идёт дальше.
typedef OutboxHandler = Future<void> Function(String userId, OutboxEntry entry);

/// Реестр обработчиков по `kind`: `report` (T20), `duelAnswer` (T23). Записи без обработчика остаются в outbox нетронутыми.
typedef OutboxHandlers = Map<OutboxKind, OutboxHandler>;
