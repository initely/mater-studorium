import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/domain/sync_coordinator.dart';
import 'package:mater_studorium/core/sync/domain/sync_report.dart';
import 'package:mater_studorium/core/sync/domain/sync_service.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  var cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  late List<_FakeTimer> timers;
  late List<SyncOutcome> outcomes;
  late int runs;

  SyncCoordinator make() {
    timers = [];
    runs = 0;
    return SyncCoordinator(
      sync: () async {
        final outcome = outcomes[runs++ % outcomes.length];
        return SyncReport(
          outcome: outcome,
          error: outcome == SyncOutcome.offline
              ? const NetworkError('x')
              : null,
        );
      },
      timer: (d, cb) {
        final t = _FakeTimer(d, cb);
        timers.add(t);
        return t;
      },
    );
  }

  _FakeTimer pending() => timers.where((t) => !t.cancelled).single;

  test('пауза: 5 с, удвоение, не больше 5 минут', () {
    expect(syncBackoff(1), const Duration(seconds: 5));
    expect(syncBackoff(2), const Duration(seconds: 10));
    expect(syncBackoff(4), const Duration(seconds: 40));
    expect(syncBackoff(7), const Duration(minutes: 5));
    expect(syncBackoff(1000), const Duration(minutes: 5));
  });

  test('без сети: повторы с нарастающей паузой; после успеха — раз в '
      'период', () async {
    outcomes = [
      SyncOutcome.offline,
      SyncOutcome.offline,
      SyncOutcome.offline,
      SyncOutcome.success,
    ];
    final c = make()..start();
    await pumpEventQueue();
    expect(pending().duration, const Duration(seconds: 5));

    pending().callback();
    await pumpEventQueue();
    expect(pending().duration, const Duration(seconds: 10));
    pending().callback();
    await pumpEventQueue();
    expect(pending().duration, const Duration(seconds: 20));
    expect(c.failures, 3);

    pending().callback();
    await pumpEventQueue();
    expect(c.failures, 0);
    expect(pending().duration, const Duration(minutes: 5));
    expect(runs, 4);
    c.dispose();
  });

  test('запрос (конец сессии, возврат в приложение) отменяет ожидающий '
      'повтор и запускает прогон сразу', () async {
    outcomes = [SyncOutcome.offline, SyncOutcome.success];
    final c = make()..start();
    await pumpEventQueue();
    final waiting = pending();

    await c.requestSync();

    expect(waiting.cancelled, isTrue);
    expect(runs, 2);
    expect(pending().duration, const Duration(minutes: 5));
    c.dispose();
  });

  test('до start() запрос работает, но расписания нет', () async {
    outcomes = [SyncOutcome.success];
    final c = make();
    await c.requestSync();
    expect(runs, 1);
    expect(timers, isEmpty);
  });

  test('dispose: таймер отменён, новые запросы не запускают прогон', () async {
    outcomes = [SyncOutcome.offline];
    final c = make()..start();
    await pumpEventQueue();
    final t = pending();
    c.dispose();
    expect(t.cancelled, isTrue);
    expect(await c.requestSync(), isNull);
    expect(runs, 1);
  });
}
