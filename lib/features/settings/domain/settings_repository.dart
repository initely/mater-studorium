import 'user_settings.dart';

/// Хранилище настроек пользователя. Реализация в `data/`. Ошибки хранилища —
/// `LocalStorageError`. Значения вне допустимых границ приводятся к границам
/// при чтении и записи.
abstract interface class SettingsRepository {
  Future<UserSettings> load();

  Future<void> setOnboardingDone(bool done);

  Future<void> setNewPerDay(int value);

  Future<void> setSessionSize(int value);

  Future<void> setReminderEnabled(bool enabled);

  /// Минуты от местной полуночи, 0..1439.
  Future<void> setReminderMinuteOfDay(int minuteOfDay);
}
