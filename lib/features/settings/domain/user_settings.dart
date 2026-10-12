import '../../session/domain/session_settings.dart';

/// Границы настроек, которые меняет пользователь (экран настроек и экран
/// колоды).
const int kMinNewPerDay = 0;
const int kMaxNewPerDay = 50;
const int kMinSessionSize = 5;
const int kMaxSessionSize = 100;

/// Шаг изменения размера сессии на экране настроек.
const int kSessionSizeStep = 5;

/// Локальные настройки пользователя (ADR-27). Хранятся на устройстве.
class UserSettings {
  const UserSettings({
    this.onboardingDone = false,
    this.newPerDay = kDefaultNewPerDay,
    this.sessionSize = kDefaultSessionSize,
  });

  /// Онбординг пройден (или пропущен): больше не показывается.
  final bool onboardingDone;

  /// Дневной лимит новых знаний (ТЗ M3, по умолчанию 10).
  final int newPerDay;

  /// Сколько знаний максимум в очереди одной сессии.
  final int sessionSize;

  UserSettings copyWith({
    bool? onboardingDone,
    int? newPerDay,
    int? sessionSize,
  }) => UserSettings(
    onboardingDone: onboardingDone ?? this.onboardingDone,
    newPerDay: newPerDay ?? this.newPerDay,
    sessionSize: sessionSize ?? this.sessionSize,
  );

  /// Настройки построителя очереди (без ограничения по колодам).
  SessionSettings toSessionSettings() =>
      SessionSettings(sessionSize: sessionSize, newPerDay: newPerDay);
}
