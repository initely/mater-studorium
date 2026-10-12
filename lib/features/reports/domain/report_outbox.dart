import 'dart:convert';

import '../../../core/sync/outbox_entry.dart';
import 'report.dart';

/// Запись очереди отправки для [report] (ТЗ §7.3): `payload_json` — тело
/// RPC `submit_report`. [now] — UTC, время создания записи.
OutboxEntry reportOutboxEntry(Report report, DateTime now) => OutboxEntry(
  kind: OutboxKind.report,
  payloadJson: jsonEncode(report.toJson()),
  createdAt: now,
);
