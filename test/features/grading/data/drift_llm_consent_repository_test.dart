import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/db/settings_dao.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/grading/data/drift_llm_consent_repository.dart';
import 'package:mater_studorium/features/grading/domain/llm_consent.dart';

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
  late DriftLlmConsentRepository repo;

  setUp(() {
    db = memoryDb();
    repo = DriftLlmConsentRepository(db.settingsDao);
  });
  tearDown(() => db.close());

  test('по умолчанию не спрашивали', () async {
    expect(await repo.load(), LlmConsent.unknown);
  });

  test('согласие и отказ сохраняются и читаются', () async {
    await repo.save(LlmConsent.granted);
    expect(await repo.load(), LlmConsent.granted);
    await repo.save(LlmConsent.declined);
    expect(await repo.load(), LlmConsent.declined);
    // Переживает новый экземпляр (перезапуск).
    expect(
      await DriftLlmConsentRepository(db.settingsDao).load(),
      LlmConsent.declined,
    );
    await repo.save(LlmConsent.unknown);
    expect(await repo.load(), LlmConsent.unknown);
  });

  test('мусор в хранилище — спросим снова', () async {
    await db.settingsDao.write('llm_consent', 'maybe');
    expect(await repo.load(), LlmConsent.unknown);
  });

  test('ошибка хранилища — LocalStorageError', () async {
    final broken = DriftLlmConsentRepository(_BrokenDao(db));
    await expectLater(broken.load(), throwsA(isA<LocalStorageError>()));
    await expectLater(
      broken.save(LlmConsent.granted),
      throwsA(isA<LocalStorageError>()),
    );
  });
}
