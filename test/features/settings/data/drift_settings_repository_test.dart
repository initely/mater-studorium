import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/db/settings_dao.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/settings/data/drift_settings_repository.dart';
import 'package:mater_studorium/features/settings/domain/user_settings.dart';

import '../../../helpers/db_fixtures.dart';

/// DAO, который падает сырым исключением.
class _BrokenDao extends SettingsDao {
  _BrokenDao(super.db);

  @override
  Future<Map<String, String>> readAll() => throw Exception('диск');

  @override
  Future<void> write(String key, String value) => throw Exception('диск');
}

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repo;

  setUp(() {
    db = memoryDb();
    repo = DriftSettingsRepository(db.settingsDao);
  });

  test('пустое хранилище: умолчания, онбординг не пройден', () async {
    final s = await repo.load();
    expect(s.onboardingDone, isFalse);
    expect(s.newPerDay, 10);
    expect(s.sessionSize, 30);
  });

  test('значения сохраняются между чтениями', () async {
    await repo.setOnboardingDone(true);
    await repo.setNewPerDay(3);
    await repo.setSessionSize(45);
    final s = await DriftSettingsRepository(db.settingsDao).load();
    expect(s.onboardingDone, isTrue);
    expect(s.newPerDay, 3);
    expect(s.sessionSize, 45);
  });

  test('значения вне границ приводятся к границам при записи', () async {
    await repo.setNewPerDay(999);
    await repo.setSessionSize(0);
    var s = await repo.load();
    expect(s.newPerDay, kMaxNewPerDay);
    expect(s.sessionSize, kMinSessionSize);
    await repo.setNewPerDay(-4);
    s = await repo.load();
    expect(s.newPerDay, kMinNewPerDay);
  });

  test('битое значение в хранилище не ломает запуск', () async {
    await db.settingsDao.write('new_per_day', 'abc');
    await db.settingsDao.write('session_size', '100000');
    final s = await repo.load();
    expect(s.newPerDay, 10);
    expect(s.sessionSize, kMaxSessionSize);
  });

  test('ошибка БД превращается в LocalStorageError', () async {
    final broken = DriftSettingsRepository(_BrokenDao(db));
    expect(broken.load(), throwsA(isA<LocalStorageError>()));
    expect(broken.setNewPerDay(5), throwsA(isA<LocalStorageError>()));
  });

  test('UserSettings.toSessionSettings: лимит и размер сессии', () {
    const s = UserSettings(newPerDay: 4, sessionSize: 15);
    final session = s.toSessionSettings();
    expect(session.newPerDay, 4);
    expect(session.sessionSize, 15);
    expect(session.deckIds, isNull);
    expect(session.forDeck('d').deckIds, {'d'});
  });
}
