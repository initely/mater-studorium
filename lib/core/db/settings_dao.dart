import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

part 'settings_dao.g.dart';

/// Настройки «ключ -> значение» (таблица `app_settings`, ADR-27). Значения —
/// строки; разбор и значения по умолчанию — в репозитории настроек.
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  Future<Map<String, String>> readAll() async {
    final rows = await select(appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<void> write(String key, String value) => into(appSettings).insert(
    AppSettingsCompanion.insert(key: key, value: value),
    mode: InsertMode.insertOrReplace,
  );
}
