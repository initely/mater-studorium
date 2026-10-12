// Обработчик outbox для жалоб (T20, ADR-33 п. 5): что пробрасывается, а что
// съедается. Ошибки сети, доступа и лимита не должны отбрасывать жалобу.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/domain/report_outbox_handler.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/features/reports/domain/report.dart';
import 'package:mater_studorium/features/reports/domain/report_outbox.dart';
import 'package:mater_studorium/features/reports/domain/report_reason.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_fixtures.dart';

OutboxEntry _entry({int attempts = 0, String? payload}) => OutboxEntry(
  kind: OutboxKind.report,
  payloadJson:
      payload ??
      reportOutboxEntry(
        Report.question(
          id: 'aaaaaaaa-0000-4000-8000-000000000001',
          deckId: 'infosec',
          deckVersion: 1,
          questionId: 'xss.q1',
          reason: ReportReason.typo,
        ),
        s0,
      ).payloadJson,
  createdAt: s0,
  attempts: attempts,
);

void main() {
  late FakeSyncServer server;
  setUp(() => server = FakeSyncServer(now: () => s0, sessionUserId: userA));

  Future<void> run(OutboxEntry e) => reportOutboxHandler(server)(userA, e);

  test('успех: отправлено, ничего не брошено', () async {
    await run(_entry());
    expect(server.reports, hasLength(1));
  });

  test('сеть и доступ пробрасываются при любом числе попыток: жалоба не '
      'теряется', () async {
    for (final attempts in [0, 2, 10]) {
      server.offline = true;
      await expectLater(
        run(_entry(attempts: attempts)),
        throwsA(isA<NetworkError>()),
      );
      server
        ..offline = false
        ..sessionUserId = userB;
      await expectLater(
        run(_entry(attempts: attempts)),
        throwsA(isA<AuthError>()),
      );
      server.sessionUserId = userA;
    }
    expect(server.reports, isEmpty);
  });

  test('лимит пробрасывается при любом числе попыток', () async {
    server.reportLimit = 0;
    for (final attempts in [0, 2, 10]) {
      await expectLater(
        run(_entry(attempts: attempts)),
        throwsA(isA<QuotaExceededError>()),
      );
    }
  });

  test(
    'отказ сервера: две попытки пробрасываются, третья отбрасывается',
    () async {
      server.rejectReport = (_) => true;
      for (final attempts in [0, 1]) {
        await expectLater(
          run(_entry(attempts: attempts)),
          throwsA(isA<SyncRejectedError>()),
        );
      }
      await run(_entry(attempts: kMaxRejectedReportAttempts - 1));
      await run(_entry(attempts: 7));
    },
  );

  test('нечитаемая и невалидная запись отбрасывается без обращения к '
      'серверу', () async {
    await run(_entry(payload: '{не json'));
    await run(_entry(payload: jsonEncode({'reason': 'spam'})));
    await run(
      _entry(
        payload: jsonEncode(
          Report.question(
            id: 'не-uuid',
            deckId: 'infosec',
            deckVersion: 1,
            questionId: 'xss.q1',
            reason: ReportReason.typo,
          ).toJson(),
        ),
      ),
    );
    expect(server.callLog, isEmpty);
  });
}
