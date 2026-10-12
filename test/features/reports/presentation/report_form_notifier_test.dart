// Состояние шторки жалобы (T20, M11): причина обязательна, двойной тап шлёт
// одну запись, сбой локальной БД не теряет введённое и даёт повторить.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/reports/data/reports_providers.dart';
import 'package:mater_studorium/features/reports/domain/report_reason.dart';
import 'package:mater_studorium/features/reports/domain/reports_repository.dart';
import 'package:mater_studorium/features/reports/presentation/report_form_notifier.dart';

class _FakeReports implements ReportsRepository {
  final calls = <({String question, ReportReason reason, String? comment})>[];
  Completer<void>? gate;
  var failNext = false;

  @override
  Future<void> reportQuestion({
    required String deckId,
    required int deckVersion,
    required String questionId,
    required String questionText,
    required ReportReason reason,
    String? comment,
  }) async {
    calls.add((question: questionId, reason: reason, comment: comment));
    await gate?.future;
    if (failNext) {
      failNext = false;
      throw const LocalStorageError('запись не удалась');
    }
  }
}

void main() {
  late _FakeReports repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeReports();
    container = ProviderContainer(
      overrides: [reportsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(reportFormProvider, (_, _) {});
  });

  ReportFormNotifier notifier() => container.read(reportFormProvider.notifier);
  ReportFormState state() => container.read(reportFormProvider);
  Future<bool> send() => notifier().send(
    deckId: 'infosec',
    deckVersion: 1,
    questionId: 'xss.q1',
    questionText: 'Что такое XSS?',
    comment: 'коммент',
  );

  test(
    'без причины отправить нельзя и в репозиторий ничего не уходит',
    () async {
      expect(state().canSend, isFalse);
      expect(await send(), isFalse);
      expect(repo.calls, isEmpty);
    },
  );

  test(
    'причина выбрана: запись в репозиторий с причиной и комментарием',
    () async {
      notifier().select(ReportReason.typo);
      expect(state().canSend, isTrue);
      expect(await send(), isTrue);
      expect(repo.calls.single, (
        question: 'xss.q1',
        reason: ReportReason.typo,
        comment: 'коммент',
      ));
    },
  );

  test(
    'двойной тап: одна запись; причину во время записи не сменить',
    () async {
      repo.gate = Completer();
      notifier().select(ReportReason.unclear);
      final first = send();
      final second = send();
      expect(state().status, ReportFormStatus.saving);
      expect(state().canSend, isFalse);
      notifier().select(ReportReason.other);
      expect(state().reason, ReportReason.unclear);
      repo.gate!.complete();
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(repo.calls, hasLength(1));
    },
  );

  test(
    'сбой локальной БД: failed, причина сохранена, повтор проходит',
    () async {
      repo.failNext = true;
      notifier().select(ReportReason.wrongAnswer);
      expect(await send(), isFalse);
      expect(state().status, ReportFormStatus.failed);
      expect(state().reason, ReportReason.wrongAnswer);
      expect(state().canSend, isTrue);
      expect(await send(), isTrue);
      expect(repo.calls, hasLength(2));
    },
  );
}
