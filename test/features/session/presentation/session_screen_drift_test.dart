// Экран сессии на реальной локальной БД (drift в памяти) и колоде
// `content/decks/sample.json`: ответы действительно попадают в `review_logs` и
// `user_item_state` (ТЗ M3, AC3.2, CLAUDE.md, правило 4).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database_providers.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/presentation/session_screen.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/deck_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/session_db_fixtures.dart';
import '../../../helpers/unmount_app.dart';

void main() {
  testWidgets('sample.json: mcq и flip проходятся, ответы записаны в drift', (
    tester,
  ) async {
    final db = memoryDb();
    await db.decksDao.replaceDeck(
      Deck.fromJson(readJsonFile(sampleDeckPath)),
      downloadedAt: t0,
    );
    var ids = 0;
    await tester.pumpApp(
      const SessionScreen(),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sessionUserIdProvider.overrideWithValue(() => sessionUser),
        clockProvider.overrideWithValue(() => t0),
        randomProvider.overrideWithValue(math.Random(1)),
        uuidGeneratorProvider.overrideWithValue(() => 'log-${ids++}'),
      ],
    );
    await tester.pumpAndSettle();

    // Очередь: новые знания по порядку колоды, cloze/order/open/find_error
    // в приложении пока не поддерживаются и пропущены: mcq (xss) и flip (hsts).
    expect(find.text('Вопрос 1 из 2'), findsOneWidget);
    expect(
      find.text(
        'Что отличает отражённую (reflected) XSS от хранимой (stored)?',
      ),
      findsOneWidget,
    );

    // mcq: верный вариант «a» (порядок вариантов перемешан, ищем по ключу).
    await tester.tap(find.byKey(const Key('mcq-option-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-next')));
    await tester.pumpAndSettle();

    // flip.
    expect(find.text('Вопрос 2 из 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flip-show')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-hard')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-summary-title')), findsOneWidget);
    expect(find.text('Повторено: 2'), findsOneWidget);

    final logs = await db.select(db.reviewLogs).get();
    expect(logs.map((l) => l.questionId).toSet(), {
      'infosec.xss.reflected.q1',
      'infosec.http.hsts.q1',
    });
    expect(
      logs.firstWhere((l) => l.questionId == 'infosec.xss.reflected.q1').rating,
      Rating.good.code,
    );
    expect(
      logs.firstWhere((l) => l.questionId == 'infosec.http.hsts.q1').rating,
      Rating.hard.code,
    );
    final states = await db.select(db.userItemStates).get();
    expect(states.map((s) => s.itemId).toSet(), {
      'infosec.xss.reflected',
      'infosec.http.hsts',
    });
    expect(states.every((s) => s.dirty), isTrue);

    await tester.unmountApp();
  });
}
