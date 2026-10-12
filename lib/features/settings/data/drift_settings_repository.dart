import '../../../core/db/settings_dao.dart';
import '../../../core/errors/app_error.dart';
import '../domain/settings_repository.dart';
import '../domain/user_settings.dart';

const _kOnboardingDone = 'onboarding_done';
const _kNewPerDay = 'new_per_day';
const _kSessionSize = 'session_size';

/// [SettingsRepository] поверх таблицы `app_settings` (ADR-27).
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._dao);

  final SettingsDao _dao;

  @override
  Future<UserSettings> load() => _guard(() async {
    final map = await _dao.readAll();
    const defaults = UserSettings();
    return UserSettings(
      onboardingDone: map[_kOnboardingDone] == '1',
      newPerDay: _int(
        map[_kNewPerDay],
        defaults.newPerDay,
        kMinNewPerDay,
        kMaxNewPerDay,
      ),
      sessionSize: _int(
        map[_kSessionSize],
        defaults.sessionSize,
        kMinSessionSize,
        kMaxSessionSize,
      ),
    );
  });

  @override
  Future<void> setOnboardingDone(bool done) =>
      _guard(() => _dao.write(_kOnboardingDone, done ? '1' : '0'));

  @override
  Future<void> setNewPerDay(int value) => _guard(
    () => _dao.write(
      _kNewPerDay,
      value.clamp(kMinNewPerDay, kMaxNewPerDay).toString(),
    ),
  );

  @override
  Future<void> setSessionSize(int value) => _guard(
    () => _dao.write(
      _kSessionSize,
      value.clamp(kMinSessionSize, kMaxSessionSize).toString(),
    ),
  );

  /// Битое значение в хранилище не должно ломать запуск: берём умолчание.
  static int _int(String? raw, int fallback, int min, int max) {
    final parsed = int.tryParse(raw ?? '');
    return parsed == null ? fallback : parsed.clamp(min, max);
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Exception catch (e) {
      throw LocalStorageError('ошибка локальных настроек', cause: e);
    }
  }
}
