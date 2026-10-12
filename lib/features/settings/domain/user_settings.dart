import '../../session/domain/session_settings.dart';

/// Границы настроек, которые меняет пользователь (экран настроек и экран
/// колоды).
const int kMinNewPerDay = 0;
const int kMaxNewPerDay = 50;
const int kMinSessionSize = 5;
const int kMaxSessionSize = 100;

/// Шаг изменения размера сессии на экране настроек.
const int kSessionSizeStep = 5;

/// Время напоминания по умолчанию: 20:00 (минуты от местной полуночи).
const int kDefaultReminderMinuteOfDay = 20 * 60;
const int kMinReminderMinuteOfDay = 0;
const int kMaxReminderMinuteOfDay = 24 * 60 - 1;

/// Локальные настройки пользователя (ADR-27). Хранятся на устройстве.
class UserSettings {
  const UserSettings({
    this.onboardingDone = false,
    this.newPerDay = kDefaultNewPerDay,
    this.sessionSize = kDefaultSessionSize,
    this.reminderEnabled = false,
    this.reminderMinuteOfDay = kDefaultReminderMinuteOfDay,
  });

  /// Онбординг пройден (или пропущен): больше не показывается.
  final bool onboardingDone;

  /// Дневной лимит новых знаний (ТЗ M3, по умолчанию 10).
  final int newPerDay;

  /// Сколько знаний максимум в очереди одной сессии.
  final int sessionSize;

  /// Ежедневное напоминание включено (ТЗ M9, ADR-29). По умолчанию выключено:
  /// включает пользователь, и тогда Android спрашивает разрешение.
  final bool reminderEnabled;

  /// Время напоминания, минуты от местной полуночи (0..1439).
  final int reminderMinuteOfDay;

  UserSettings copyWith({
    bool? onboardingDone,
    int? newPerDay,
    int? sessionSize,
    bool? reminderEnabled,
    int? reminderMinuteOfDay,
  }) => UserSettings(
    onboardingDone: onboardingDone ?? this.onboardingDone,
    newPerDay: newPerDay ?? this.newPerDay,
    sessionSize: sessionSize ?? this.sessionSize,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinuteOfDay: reminderMinuteOfDay ?? this.reminderMinuteOfDay,
  );

  /// Настройки построителя очереди (без ограничения по колодам).
  SessionSettings toSessionSettings() =>
      SessionSettings(sessionSize: sessionSize, newPerDay: newPerDay);
}
