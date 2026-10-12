// Нужно ли напоминать (T19, AC9.1, ТЗ M9): день пропускается, если к моменту
// напоминания ничего не пора повторять; сессия сдвигает `due`; отказ в
// разрешении и выключенный тумблер ничего не ставят. Часы фиксированные.
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/reminders/domain/reminder_service.dart';
import 'package:mater_studorium/features/reminders/domain/reminder_texts.dart';

import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/fake_session_repository.dart';
import '../../../helpers/time_zones.dart';

const _texts = ReminderTexts(
  title: 'Пора',
  body: 'Повторить',
  channelName: 'Канал',
  channelDescription: 'Описание',
);

// 13:00 в +03:00; напоминание в 20:00 (17:00Z).
final _now = DateTime.utc(2026, 10, 12, 10);
const _evening = 20 * 60;

FakeSessionRepository repoWith(Map<String, DateTime> dues) =>
    FakeSessionRepository(
      contents: [for (final id in dues.keys) fakeContent(id)],
      states: {for (final e in dues.entries) e.key: fakeState(e.key, e.value)},
    );

ReminderService serviceFor(
  FakeNotificationScheduler scheduler,
  FakeSessionRepository repo, {
  Duration Function(DateTime)? offsetAt,
}) => ReminderService(
  scheduler: scheduler,
  repository: repo,
  offsetAt: offsetAt ?? fixedOffset(hm(3)),
);

Future<ReminderResult> run(
  ReminderService service, {
  bool enabled = true,
  int minuteOfDay = _evening,
  DateTime? now,
}) => service.reschedule(
  enabled: enabled,
  minuteOfDay: minuteOfDay,
  now: now ?? _now,
  texts: _texts,
);

void main() {
  late FakeNotificationScheduler scheduler;

  setUp(() => scheduler = FakeNotificationScheduler());

  group('есть что повторять', () {
    test(
      'просрочено сейчас: напоминания на все 7 дней, первое сегодня',
      () async {
        final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 8)});
        final result = await run(serviceFor(scheduler, repo));

        expect(result.status, ReminderStatus.scheduled);
        expect(scheduler.scheduled, hasLength(7));
        expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 12, 17));
        expect(scheduler.scheduled, result.scheduled);
        expect(scheduler.texts?.title, 'Пора');
      },
    );

    test('due наступит сегодня до 20:00: сегодняшнее ставится', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 16, 59)});
      await run(serviceFor(scheduler, repo));
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 12, 17));
    });

    test('due ровно в момент напоминания: считается', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 17)});
      await run(serviceFor(scheduler, repo));
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 12, 17));
    });
  });

  group('нечего повторять', () {
    test('ни одного состояния (колоды нет или всё новое): ничего', () async {
      final result = await run(serviceFor(scheduler, repoWith({})));
      expect(result.status, ReminderStatus.scheduled);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.replaceCalls, 1, reason: 'старые напоминания сняты');
    });

    test('due после 20:00 сегодня: сегодня пропуск, дальше есть', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 17, 1)});
      await run(serviceFor(scheduler, repo));
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 13, 17));
      expect(scheduler.scheduled, hasLength(6));
    });

    test('due через 3 дня: напоминаний нет до этого дня', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 10, 15, 9)});
      await run(serviceFor(scheduler, repo));
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 15, 17));
      expect(scheduler.scheduled, hasLength(4)); // 15, 16, 17, 18 октября
    });

    test('due дальше недели: ничего не ставится', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 11, 1)});
      await run(serviceFor(scheduler, repo));
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('после сессии (повторное перепланирование)', () {
    test('ответили на всё: сегодняшнее напоминание исчезает', () async {
      final repo = repoWith({
        'a': DateTime.utc(2026, 10, 12, 8),
        'b': DateTime.utc(2026, 10, 12, 9),
      });
      final service = serviceFor(scheduler, repo);
      await run(service);
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 12, 17));

      // Сессия: FSRS отодвинул оба знания на завтра днём.
      repo.states['a'] = fakeState('a', DateTime.utc(2026, 10, 13, 12));
      repo.states['b'] = fakeState('b', DateTime.utc(2026, 10, 14, 12));
      await run(service, now: DateTime.utc(2026, 10, 12, 10, 5));

      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 13, 17));
      expect(scheduler.scheduled, hasLength(6));
    });

    test(
      'ответили не на всё: остаток по-прежнему due, напоминание есть',
      () async {
        final repo = repoWith({
          'a': DateTime.utc(2026, 10, 12, 8),
          'b': DateTime.utc(2026, 10, 12, 9),
        });
        final service = serviceFor(scheduler, repo);
        repo.states['a'] = fakeState('a', DateTime.utc(2026, 10, 20));
        await run(service);
        // ТЗ M9: решает «пора ли что-то повторять к этому времени», а не
        // «была ли сессия» (ADR-29).
        expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 12, 17));
      },
    );
  });

  group('смена настроек', () {
    test('новое время: расписание заменяется целиком', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 8)});
      final service = serviceFor(scheduler, repo);
      await run(service);
      final first = List.of(scheduler.scheduled);

      await run(service, minuteOfDay: 21 * 60 + 15);
      expect(scheduler.scheduled, hasLength(7));
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 12, 18, 15));
      expect(scheduler.scheduled, isNot(first));
      expect(scheduler.replaceCalls, 2);
    });

    test('время раньше текущего: сегодня пропуск, завтра первое', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 8)});
      await run(serviceFor(scheduler, repo), minuteOfDay: 9 * 60);
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 13, 6));
    });

    test('выключили: всё отменено', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 8)});
      final service = serviceFor(scheduler, repo);
      await run(service);
      final result = await run(service, enabled: false);

      expect(result.status, ReminderStatus.disabled);
      expect(scheduler.scheduled, isEmpty);
    });

    test('смена часового пояса: те же 20:00, другие моменты UTC', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 8)});
      await run(serviceFor(scheduler, repo, offsetAt: fixedOffset(hm(3))));
      final moscow = scheduler.scheduled.first;
      await run(serviceFor(scheduler, repo, offsetAt: fixedOffset(hm(9))));
      expect(moscow, DateTime.utc(2026, 10, 12, 17));
      expect(scheduler.scheduled.first, DateTime.utc(2026, 10, 12, 11));
    });
  });

  group('разрешение и платформа', () {
    test('нет разрешения: всё снято, статус «отказано», без ошибок', () async {
      scheduler.granted = false;
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 8)});
      final result = await run(serviceFor(scheduler, repo));

      expect(result.status, ReminderStatus.permissionDenied);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.requestCalls, 0, reason: 'диалог только по тумблеру');
    });

    test(
      'разрешение вернули в системных настройках: напоминания встают',
      () async {
        scheduler.granted = false;
        final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 8)});
        final service = serviceFor(scheduler, repo);
        await run(service);
        scheduler.granted = true;
        final result = await run(service);

        expect(result.status, ReminderStatus.scheduled);
        expect(scheduler.scheduled, hasLength(7));
      },
    );

    test('платформа без напоминаний (web): ничего не вызывается', () async {
      final web = FakeNotificationScheduler(supported: false);
      final repo = repoWith({'a': DateTime.utc(2026, 10, 12, 8)});
      final result = await run(serviceFor(web, repo));

      expect(result.status, ReminderStatus.unsupported);
      expect(web.initializeCalls, 0);
      expect(web.replaceCalls, 0);
    });
  });

  group('переход на летнее время', () {
    test('20:00 в Нью-Йорке: каждый день одни и те же часы на стене', () async {
      final repo = repoWith({'a': DateTime.utc(2026, 3, 1)});
      await run(
        serviceFor(scheduler, repo, offsetAt: newYork),
        now: DateTime.utc(2026, 3, 6, 15),
      );
      expect(scheduler.scheduled.take(4).toList(), [
        DateTime.utc(2026, 3, 7, 1),
        DateTime.utc(2026, 3, 8, 1),
        DateTime.utc(2026, 3, 9, 0),
        DateTime.utc(2026, 3, 10, 0),
      ]);
    });

    test(
      'due в пропущенный час: напоминание 02:30 сдвинуто на 03:30',
      () async {
        // due 07:15Z 8 марта (= 03:15 EDT) раньше сдвинутого 07:30Z, но позже
        // несуществующего 02:30 EST.
        final repo = repoWith({'a': DateTime.utc(2026, 3, 8, 7, 15)});
        await run(
          serviceFor(scheduler, repo, offsetAt: newYork),
          minuteOfDay: 2 * 60 + 30,
          now: DateTime.utc(2026, 3, 6, 15),
        );
        expect(scheduler.scheduled.first, DateTime.utc(2026, 3, 8, 7, 30));
      },
    );
  });
}
