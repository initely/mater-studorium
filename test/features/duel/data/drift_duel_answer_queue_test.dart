// DriftDuelAnswerQueue: невалидный ответ не попадает в outbox и возвращает
// типизированную ошибку (ревью T23 N3).
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/data/drift_duel_answer_queue.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/duel_fixtures.dart';
import '../../../helpers/fake_duel_repository.dart';
import '../../../helpers/sync_fixtures.dart';

void main() {
  test('ответ длиннее 512 байт: InvalidDuelAnswerError, outbox пуст', () async {
    final db = memoryDb();
    final queue = DriftDuelAnswerQueue(
      db: db,
      userId: () => userA,
      clock: () => duelNow,
    );

    await expectLater(
      queue.enqueue(
        DuelAnswerPayload(
          duelId: kDuelId,
          questionId: duelQuestionIds().first,
          answer: {'selected': List.filled(100, 'option-aaaaaaaa')},
          isCorrect: true,
          durationMs: 10,
        ),
      ),
      throwsA(isA<InvalidDuelAnswerError>()),
    );
    expect(await db.select(db.outbox).get(), isEmpty);

    expect(
      await queue.enqueue(
        DuelAnswerPayload.skipped(
          duelId: kDuelId,
          questionId: duelQuestionIds().first,
        ),
      ),
      isTrue,
    );
    expect(await db.select(db.outbox).get(), hasLength(1));
  });
}
