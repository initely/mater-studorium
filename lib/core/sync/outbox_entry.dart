/// Что лежит в `outbox` (ТЗ §7.3): только то, что не покрыто `dirty` и
/// `synced_at`.
enum OutboxKind { report, duelAnswer }

/// Запись очереди отправки. [id] и [attempts] заполняются при чтении из БД.
class OutboxEntry {
  const OutboxEntry({
    required this.kind,
    required this.payloadJson,
    required this.createdAt,
    this.id,
    this.attempts = 0,
  });

  final int? id;
  final OutboxKind kind;
  final String payloadJson;

  /// UTC.
  final DateTime createdAt;
  final int attempts;
}
