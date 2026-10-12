import 'dart:async';

import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/domain/sync_remote.dart';
import 'package:mater_studorium/features/session/domain/review_log.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';

/// Сервер синхронизации в памяти с той же семантикой, что `0003_sync.sql`:
/// логи только вставляются (повтор id ничего не делает), состояния — LWW
/// строго по большему `updatedAt`, `updatedAt` из будущего зажимается к
/// `now + 2 мин`, пакет больше 500 отклоняется, данные другого пользователя
/// (не та «сессия») — `AuthError`, pull по `sync_seq`.
///
/// Сбои: [offline] — каждый вызов `NetworkError` до применения;
/// [failBefore] / [failAfter] — сбой конкретного вызова по номеру (с 1)
/// до применения или после (данные записаны, ответ потерян); [gate] —
/// вызов ждёт, пока его не откроют (проверка параллельности).
class FakeSyncServer implements SyncRemote {
  FakeSyncServer({required this.now, this.sessionUserId});

  /// Пользователь, чей JWT «в заголовке».
  String? sessionUserId;
  DateTime Function() now;

  bool offline = false;

  /// Строка, которую «сервер» не примет (как CHECK, 22P05 или PGRST102):
  /// весь пакет с ней — `SyncRejectedError`, ничего не записано.
  bool Function(Object row)? reject;

  /// Подмена ответа pull состояний (проверка неверного ответа сервера).
  PulledPage<ItemState> Function(int afterSeq, int limit)? pullStatesOverride;

  /// Сбой «неожиданного» рода (не сеть, не доступ, не отказ строки).
  final failUnexpected = <String>{};
  final failBefore = <int>{};
  final failAfter = <int>{};
  Completer<void>? gate;
  final _holds =
      <String, ({Completer<void> reached, Completer<void> release})>{};

  /// Следующий вызов [op] остановится до применения: `reached` завершится,
  /// когда вызов дошёл до сервера, вызов продолжится после `release`.
  ({Completer<void> reached, Completer<void> release}) hold(String op) =>
      _holds[op] = (reached: Completer<void>(), release: Completer<void>());

  var calls = 0;
  var _inFlight = 0;
  var maxInFlight = 0;
  final callLog = <String>[];

  var _seq = 0;
  final logs = <String, ({String userId, ReviewLog log, int seq})>{};
  final states = <(String, String), ({ItemState state, int seq})>{};

  List<ReviewLog> logsOf(String userId) => [
    for (final e in logs.values)
      if (e.userId == userId) e.log,
  ];

  ItemState? stateOf(String userId, String itemId) =>
      states[(userId, itemId)]?.state;

  /// Строка «с другого устройства» (как будто пришла через RPC).
  void putState(String userId, ItemState s) => _upsert(userId, s, clamp: false);

  void putLog(String userId, ReviewLog l) =>
      logs.putIfAbsent(l.id, () => (userId: userId, log: l, seq: ++_seq));

  Future<T> _call<T>(String op, String userId, T Function() apply) async {
    final n = ++calls;
    callLog.add(op);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      await Future<void>.delayed(Duration.zero);
      if (gate != null) await gate!.future;
      final held = _holds.remove(op);
      if (held != null) {
        held.reached.complete();
        await held.release.future;
      }
      if (offline || failBefore.contains(n)) {
        throw NetworkError('fake: нет сети ($op #$n)');
      }
      if (sessionUserId == null) throw const AuthError('fake: нет сессии');
      if (sessionUserId != userId) {
        throw const AuthError('fake: пакет другого пользователя');
      }
      if (failUnexpected.contains(op)) {
        throw UnexpectedError('fake: неожиданное ($op #$n)');
      }
      final result = apply();
      if (failAfter.contains(n)) {
        throw NetworkError('fake: ответ потерян ($op #$n)');
      }
      return result;
    } finally {
      _inFlight--;
    }
  }

  void _checkBatch(List<Object> rows) {
    if (rows.length > kMaxSyncBatch) {
      throw const SyncRejectedError('fake: больше 500 записей');
    }
    if (reject != null && rows.any(reject!)) {
      throw const SyncRejectedError('fake: пакет отклонён');
    }
  }

  DateTime get _maxUpdatedAt {
    final t = now().toUtc().add(const Duration(minutes: 2));
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }

  void _upsert(String userId, ItemState s, {bool clamp = true}) {
    final max = _maxUpdatedAt;
    final incoming = clamp && s.updatedAt.isAfter(max)
        ? s.copyWith(updatedAt: max)
        : s;
    final key = (userId, s.itemId);
    final existing = states[key];
    if (existing == null ||
        incoming.updatedAt.isAfter(existing.state.updatedAt)) {
      states[key] = (state: incoming, seq: ++_seq);
    }
  }

  @override
  Future<int> insertReviewLogs(String userId, List<ReviewLog> batch) =>
      _call('insertReviewLogs', userId, () {
        _checkBatch(batch);
        var inserted = 0;
        for (final l in batch) {
          if (logs.containsKey(l.id)) continue;
          logs[l.id] = (userId: userId, log: l, seq: ++_seq);
          inserted++;
        }
        return inserted;
      });

  @override
  Future<List<ItemState>> upsertItemStates(
    String userId,
    List<ItemState> batch,
  ) => _call('upsertItemStates', userId, () {
    _checkBatch(batch);
    for (final s in batch) {
      _upsert(userId, s);
    }
    return [
      for (final id in {for (final s in batch) s.itemId})
        states[(userId, id)]!.state,
    ];
  });

  @override
  Future<PulledPage<ItemState>> pullItemStates(
    String userId, {
    required int afterSeq,
    required int limit,
  }) => _call('pullItemStates', userId, () {
    if (pullStatesOverride != null) return pullStatesOverride!(afterSeq, limit);
    final rows = [
      for (final MapEntry(key: (u, _), :value) in states.entries)
        if (u == userId && value.seq > afterSeq) value,
    ]..sort((a, b) => a.seq.compareTo(b.seq));
    final page = rows.take(limit).toList();
    return PulledPage(
      rows: [for (final r in page) r.state],
      fetched: page.length,
      lastSeq: page.isEmpty ? null : page.last.seq,
    );
  });

  @override
  Future<PulledPage<ReviewLog>> pullReviewLogs(
    String userId, {
    required int afterSeq,
    required int limit,
  }) => _call('pullReviewLogs', userId, () {
    final rows = [
      for (final e in logs.values)
        if (e.userId == userId && e.seq > afterSeq) e,
    ]..sort((a, b) => a.seq.compareTo(b.seq));
    final page = rows.take(limit).toList();
    return PulledPage(
      rows: [for (final r in page) r.log],
      fetched: page.length,
      lastSeq: page.isEmpty ? null : page.last.seq,
    );
  });
}
