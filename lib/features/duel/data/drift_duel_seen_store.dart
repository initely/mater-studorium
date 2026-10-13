import 'dart:convert';

import '../../../core/db/settings_dao.dart';
import '../../../core/errors/app_error.dart';
import '../domain/duel_seen_store.dart';

/// Ключ `app_settings`: JSON-массив id дуэлей с открытым результатом.
const kDuelSeenResultsSettingKey = 'duel.results_seen';

/// Сколько последних id хранить (дуэли живут недели, список не растёт).
const kDuelSeenResultsLimit = 100;

/// [DuelSeenStore] поверх `app_settings`. Битое значение считается пустым.
class DriftDuelSeenStore implements DuelSeenStore {
  DriftDuelSeenStore(this._settings);

  final SettingsDao _settings;

  @override
  Future<Set<String>> seenResults() async {
    try {
      return (await _read()).toSet();
    } on Exception catch (e) {
      throw LocalStorageError(
        'не удалось прочитать открытые результаты',
        cause: e,
      );
    }
  }

  @override
  Future<void> markResultSeen(String duelId) async {
    try {
      final ids = await _read();
      if (ids.contains(duelId)) return;
      final next = [...ids, duelId];
      final trimmed = next.length > kDuelSeenResultsLimit
          ? next.sublist(next.length - kDuelSeenResultsLimit)
          : next;
      await _settings.write(kDuelSeenResultsSettingKey, jsonEncode(trimmed));
    } on Exception catch (e) {
      throw LocalStorageError(
        'не удалось сохранить открытый результат',
        cause: e,
      );
    }
  }

  Future<List<String>> _read() async {
    final raw = (await _settings.readAll())[kDuelSeenResultsSettingKey];
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      return json is List
          ? [
              for (final e in json)
                if (e is String) e,
            ]
          : const [];
    } on FormatException {
      return const [];
    }
  }
}
