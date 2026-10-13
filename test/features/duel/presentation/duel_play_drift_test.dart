// Игра в дуэль на настоящей локальной БД (drift в памяти): ответы идут только
// в outbox, FSRS не затронут (ADR-16, CLAUDE.md правило 4), затем уходят на
// сервер через SyncService (T23, ADR-36).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/sync/domain/duel_answer_outbox_handler.dart';
import 'package:mater_studorium/core/sync/domain/sync_service.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/features/duel/data/drift_duel_answer_queue.dart';
import 'package:mater_studorium/features/duel/data/drift_duel_content_source.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/duel_fixtures.dart';
import '../../../helpers/fake_catalog_repository.dart';
import '../../../helpers/fake_duel_repository.dart';
import '../../../helpers/fake_sync_server.dart';
import '../../../helpers/session_db_fixtures.dart';
import '../../../helpers/sync_fixtures.dart';
import '../../../helpers/unmount_app.dart';
import 'duel_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

void main() {
  late AppDatabase db;
  late FakeDuelRepository repo;

  setUp(() {
    db = memoryDb();
    repo = FakeDuelRepository()..getResult = playDuel();
  });

  Future<void> open(WidgetTester tester, {String path = ''}) => pumpDuelApp(
    tester,
    initial: '/duels/$kDuelId$path',
    repo: repo,
    catalog: FakeCatalogRepository(local: [localDeck(kDuelDeckId, version: 2)]),
    queue: DriftDuelAnswerQueue(
      db: db,
      userId: () => sessionUser,
      clock: () => duelNow,
    ),
    content: DriftDuelContentSource(db.decksDao),
  );

  Future<List<OutboxRow>> outbox() => db.select(db.outbox).get();

  Future<void> play(WidgetTester tester, List<String> options) async {
    for (final option in options) {
      await tester.tap(_key('mcq-option-$option'));
      await tester.pumpAndSettle();
      await tester.tap(_key('duel-play-next'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('пять ответов: только outbox, review_logs и FSRS пусты, затем '
      'синк доставляет ответы', (tester) async {
    await db.decksDao.replaceDeck(duelDeck(), downloadedAt: t0);
    await open(tester, path: '/play');
    await play(tester, ['a', 'b', 'a', 'c', 'a']);
    expect(_key('duel-play-done'), findsOneWidget);

    final rows = await outbox();
    expect(rows, hasLength(5));
    expect(rows.every((r) => r.kind == OutboxKind.duelAnswer), isTrue);
    expect(rows.every((r) => r.userId == sessionUser), isTrue);
    final payloads = [
      for (final r in rows)
        DuelAnswerPayload.tryParse(jsonDecode(r.payloadJson))!,
    ];
    expect([for (final p in payloads) p.questionId], duelQuestionIds());
    expect(
      [for (final p in payloads) p.isCorrect],
      [true, false, true, false, true],
    );
    expect(payloads[1].answer, {
      'selected': ['b'],
    });

    // ADR-16: ни журнала повторений, ни состояния знаний, ни расписания.
    expect(await db.select(db.reviewLogs).get(), isEmpty);
    expect(await db.select(db.userItemStates).get(), isEmpty);

    // Доставка через SyncService.
    final server = FakeSyncServer(now: () => s0, sessionUserId: sessionUser);
    final service = SyncService(
      remote: server,
      store: db.syncDao,
      currentUserId: () => sessionUser,
      clock: () => s0,
      outboxHandlers: {OutboxKind.duelAnswer: duelAnswerOutboxHandler(server)},
    );
    // Сервер в памяти задерживает ответ на нулевой таймер: нужны настоящие часы.
    final report = (await tester.runAsync(service.sync))!;
    expect(report.outboxSent, 5, reason: '$report');
    expect(await outbox(), isEmpty);
    expect(server.duelAnswers, hasLength(5));
    expect(server.logs, isEmpty);
    expect(server.states, isEmpty);
    expect(await db.select(db.reviewLogs).get(), isEmpty);
    expect(await db.select(db.userItemStates).get(), isEmpty);
    await tester.unmountApp();
  });

  testWidgets('уже сыгранный вопрос: после перезапуска экрана игра '
      'продолжается с неотвеченного', (tester) async {
    await db.decksDao.replaceDeck(duelDeck(), downloadedAt: t0);
    await open(tester, path: '/play');
    await play(tester, ['a', 'a']);
    expect(find.text('Вопрос 3 из 5'), findsOneWidget);
    await tester.unmountApp();

    // Новый запуск: свежие провайдеры, та же БД.
    await open(tester, path: '/play');
    expect(find.text('Вопрос 3 из 5'), findsOneWidget);
    expect(await outbox(), hasLength(2));
    await tester.tap(_key('mcq-option-a'));
    await tester.pumpAndSettle();
    expect(await outbox(), hasLength(3));
    await tester.unmountApp();
  });

  testWidgets('в колоде нет двух вопросов: «сыграть без них» кладёт в outbox '
      'пропуски, остальные играются', (tester) async {
    // У соперника колода другой версии: в ней только три из пяти вопросов.
    await db.decksDao.replaceDeck(duelDeck(n: 3, version: 3), downloadedAt: t0);
    await open(tester, path: '/play');
    expect(_key('duel-play-blocked'), findsOneWidget);
    expect(
      find.textContaining('2 вопроса этой дуэли недоступны'),
      findsOneWidget,
    );

    await tester.tap(_key('duel-play-skip'));
    await tester.pumpAndSettle();
    var rows = await outbox();
    expect(rows, hasLength(2));
    final skipped = [
      for (final r in rows)
        DuelAnswerPayload.tryParse(jsonDecode(r.payloadJson))!,
    ];
    expect([for (final p in skipped) p.questionId], duelQuestionIds().skip(3));
    expect(
      skipped.every((p) => !p.isCorrect && p.answer['skipped'] == true),
      isTrue,
    );

    await play(tester, ['a', 'a', 'a']);
    expect(_key('duel-play-done'), findsOneWidget);
    rows = await outbox();
    expect(rows, hasLength(5));
    expect(await db.select(db.reviewLogs).get(), isEmpty);
    await tester.unmountApp();
  });
}
