import '../../../features/auth/domain/account_intent.dart';
import '../../../features/auth/domain/auth_user.dart';
import '../../../features/session/domain/review_log.dart';
import '../../../features/srs/domain/item_state.dart';
import '../outbox_entry.dart';

/// Поток pull и его курсор.
enum SyncStream {
  itemStates('item_states'),
  reviewLogs('review_logs');

  const SyncStream(this.wire);

  /// Ключ в таблице курсоров.
  final String wire;
}

/// Локальная сторона синхронизации (локальная БД). Все методы работают только со
/// строками [userId]; сбои выходят как `LocalStorageError`.
abstract interface class SyncStore {
  /// Неотправленные логи (`synced_at` пуст) в порядке `reviewedAt, id`,
  /// строго после [after] (keyset: пропущенные невалидные строки не
  /// мешают дойти до следующих).
  Future<List<ReviewLog>> unsyncedLogs(
    String userId, {
    required int limit,
    ReviewLog? after,
  });

  /// Сервер подтвердил приём: проставить `synced_at`.
  Future<void> markLogsSynced(String userId, List<String> ids, DateTime at);

  /// Состояния с `dirty = 1` в порядке `itemId`, строго после [afterItemId].
  Future<List<ItemState>> dirtyStates(
    String userId, {
    required int limit,
    String? afterItemId,
  });

  /// Ответ сервера на push состояний (одна транзакция): если локальная строка
  /// не менялась с отправки ([sent]), записывается серверная строка и
  /// снимается `dirty`; если менялась (новый ответ во время отправки) —
  /// слияние по [decideMerge]. Знание без строки в [server] остаётся dirty.
  Future<void> applyPushedStates(
    String userId, {
    required List<ItemState> sent,
    required List<ItemState> server,
  });

  /// Курсор pull (0 — ничего не получено).
  Future<int> cursor(String userId, SyncStream stream);

  /// Слияние страницы состояний по [decideMerge] и сдвиг курсора — одной
  /// транзакцией (курсор не убегает вперёд несохранённых данных).
  Future<void> mergePulledStates(
    String userId,
    List<ItemState> states, {
    required int cursor,
  });

  /// Логи с сервера: вставить отсутствующие (уже отправленными), сдвинуть
  /// курсор — одной транзакцией.
  Future<void> insertPulledLogs(
    String userId,
    List<ReviewLog> logs, {
    required int cursor,
    required DateTime syncedAt,
  });

  /// Список скрытых по жалобам вопросов с сервера заменяет прежний серверный
  /// список (одной транзакцией). Вопросы, скрытые самим пользователем жалобой
  /// (`source = local`), остаются: сервер о них может ещё не знать (жалоба
  /// в очереди), а после решения куратора пользователь вернул бы их сам.
  Future<void> replaceServerHiddenQuestions(Set<String> questionIds);

  /// Записи outbox пользователя по возрастанию `id`, строго после [afterId].
  Future<List<OutboxEntry>> pendingOutbox(
    String userId, {
    required int limit,
    int? afterId,
  });

  Future<void> deleteOutbox(int id);

  Future<void> markOutboxAttempt(int id);

  /// Пользователь, которому принадлежали локальные данные при прошлом входе.
  Future<AuthUser?> lastOwner();

  Future<void> saveOwner(AuthUser user);

  /// Перенести локальные данные [from] на [to] (одной транзакцией):
  /// состояния (при совпадении знания побеждает более позднее `updatedAt`,
  /// перенесённые помечаются dirty), неотправленные логи и outbox. Курсоры
  /// [from] удаляются. Правило, когда это можно, — `shouldAdoptLocalData`.
  Future<void> adoptLocalData({required String from, required String to});
}

/// Что сделать с локальной строкой при встрече с серверной.
enum MergeAction {
  /// Записать серверную строку, снять `dirty`.
  takeServer,

  /// Оставить локальную как есть.
  keepLocal,

  /// Оставить локальную и пометить `dirty`: она новее серверной, а сервер о
  /// ней не знает (например, сервер восстановлен из резервной копии).
  keepLocalMarkDirty,
}

/// LWW-слияние (ADR-14, ADR-30): побеждает больший `updatedAt`; при равенстве
/// побеждает сервер — так же решает сервер (`upsert_item_states` применяет
/// только строго более новое), поэтому все устройства сходятся к одной
/// строке. Несинхронизированная локальная строка теряется только если
/// сервер не старее её — ровно тогда её отклонил бы и сервер.
MergeAction decideMerge({
  required ItemState? local,
  required bool localDirty,
  required ItemState server,
}) {
  if (local == null) return MergeAction.takeServer;
  if (!server.updatedAt.isBefore(local.updatedAt)) {
    return MergeAction.takeServer;
  }
  return localDirty ? MergeAction.keepLocal : MergeAction.keepLocalMarkDirty;
}

/// Можно ли перенести локальные данные прежнего пользователя на нового
/// (ADR-30). Только «анонимный → анонимный»: прежний анонимный аккаунт
/// потерян (сессию не вернуть, на сервер его данные уже не попадут), и это
/// тот же человек на том же устройстве. Если прежний аккаунт не анонимный
/// (Google, T21), в него можно войти снова, а на общем устройстве его
/// прогресс не должен достаться другому человеку — данные не переносятся
/// и остаются под прежним `user_id`.
bool shouldAdoptLocalData({
  required AuthUser previous,
  required AuthUser current,
}) => previous.id != current.id && previous.isAnonymous && current.isAnonymous;

/// Можно ли перенести данные потерянного анонимного [previous] на нового
/// анонимного [current] (ADR-30): правило [shouldAdoptLocalData] и запись
/// `relogin`, которую делает приложение перед собственным повторным анонимным
/// входом (ADR-34, защита в глубину: смену пользователя «снаружи» не
/// принимаем за потерянную сессию).
bool shouldAdoptAfterRelogin({
  required AuthUser previous,
  required AuthUser current,
  required AccountIntent? intent,
}) =>
    shouldAdoptLocalData(previous: previous, current: current) &&
    intent != null &&
    intent.kind == AccountIntentKind.relogin &&
    intent.fromUserId == previous.id;

/// Можно ли перенести локальные данные анонимного [previous] на Google-
/// аккаунт [current], в который пользователь только что вошёл (T21, ADR-34).
///
/// Только по явному подтверждению: [intent] — запись `merge`, созданная после
/// нажатия «Войти и объединить», на этом же устройстве, для этого же
/// анонимного пользователя и ещё не просроченная. Без неё данные остаются
/// под прежним `user_id`, как и раньше ([shouldAdoptLocalData]): иначе чужой
/// вход на общем устройстве забрал бы прогресс прежнего владельца.
bool shouldAdoptConfirmedMerge({
  required AuthUser previous,
  required AuthUser current,
  required AccountIntent? intent,
  required DateTime now,
}) =>
    intent != null &&
    intent.kind == AccountIntentKind.merge &&
    intent.isFresh(now) &&
    previous.isAnonymous &&
    !current.isAnonymous &&
    previous.id != current.id &&
    intent.fromUserId == previous.id;
