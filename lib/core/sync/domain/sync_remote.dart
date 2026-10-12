import '../../../features/reports/domain/report.dart';
import '../../../features/session/domain/review_log.dart';
import '../../../features/srs/domain/item_state.dart';

/// Страница pull: строки, изменённые после курсора, по возрастанию
/// серверного `sync_seq`.
class PulledPage<T> {
  const PulledPage({
    required this.rows,
    required this.fetched,
    required this.lastSeq,
  });

  /// Разобранные строки. Строки, которые клиент не понимает (например, новый
  /// формат вопроса в логе с более нового клиента), сюда не попадают, но
  /// курсор их проходит.
  final List<T> rows;

  /// Сколько строк пришло от сервера (с неразобранными). Меньше лимита —
  /// страница последняя.
  final int fetched;

  /// Наибольший `sync_seq` страницы; `null`, если строк нет.
  final int? lastSeq;
}

/// Сервер синхронизации (ТЗ §7.3). Единственное место, которое знает про
/// Supabase; все сбои выходят как `AppError`:
/// `NetworkError` (нет сети, таймаут, 5xx), `AuthError` (нет сессии, сессия
/// другого пользователя, 401/403), `SyncRejectedError` (сервер отклонил пакет
/// как неверный), `UnexpectedError`.
///
/// [userId] в каждом вызове — чьи это данные. Если сессия уже принадлежит
/// другому пользователю, вызов отклоняется (`AuthError`): данные одного
/// пользователя не уходят под сессией другого.
abstract interface class SyncRemote {
  /// Идемпотентная вставка логов (`on conflict (id) do nothing`). Возвращает
  /// число новых строк на сервере. Не больше `kMaxSyncBatch` записей.
  Future<int> insertReviewLogs(String userId, List<ReviewLog> logs);

  /// LWW-запись состояний. Возвращает итоговые серверные строки всех знаний
  /// пакета: принятые (возможно, с зажатым `updatedAt`) и отклонённые (тогда
  /// это более новая серверная строка). Не больше `kMaxSyncBatch` записей.
  Future<List<ItemState>> upsertItemStates(
    String userId,
    List<ItemState> states,
  );

  /// Состояния пользователя с `sync_seq > afterSeq`, не больше [limit].
  Future<PulledPage<ItemState>> pullItemStates(
    String userId, {
    required int afterSeq,
    required int limit,
  });

  /// Логи пользователя с `sync_seq > afterSeq`, не больше [limit].
  Future<PulledPage<ReviewLog>> pullReviewLogs(
    String userId, {
    required int afterSeq,
    required int limit,
  });

  /// Отправляет жалобу или «не согласен» (RPC `submit_report`, ТЗ M11, ADR-33).
  /// Идемпотентно по `report.id`. Возвращает `true`, если сервер создал
  /// строку, и `false`, если она уже была (повтор) или это вторая жалоба
  /// пользователя на тот же вопрос. Дневной лимит жалоб — `QuotaExceededError`
  /// (повторить после полуночи UTC), отказ сервера по значению —
  /// `SyncRejectedError`.
  Future<bool> submitReport(String userId, Report report);

  /// Вопросы, скрытые по жалобам (RPC `hidden_questions`, ТЗ §5.3 п. 5,
  /// шаг 5 §7.3): весь список целиком, не страница.
  Future<Set<String>> pullHiddenQuestions(String userId);
}

/// Предел пакета на сервере (`0003_sync.sql`): больше — отказ всего пакета.
const kMaxSyncBatch = 500;
