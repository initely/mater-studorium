import 'reminder_texts.dart';

/// Куда ведёт тап по напоминанию (маршрут go_router).
const String kReminderRoute = '/session';

/// Сколько напоминаний ставим вперёд (ТЗ T19: на ближайшие 7 дней).
const int kReminderDays = 7;

/// Системное разрешение на показ уведомлений.
enum NotificationPermission { granted, denied }

/// Платформенная часть напоминаний (Android: `flutter_local_notifications`).
/// Домен о Flutter не знает: реализация лежит в `data/`, в тестах подменяется
/// fake. Все методы, кроме [isSupported], на неподдерживаемой платформе
/// ничего не делают. Ошибки платформы — `AppError`.
abstract interface class NotificationScheduler {
  /// Платформа умеет локальные напоминания. На web и вне Android — нет
  /// (ТЗ M9: на web в MVP напоминаний нет).
  bool get isSupported;

  /// Готовит плагин и подписку на тапы. Можно вызывать повторно. Разрешение
  /// не запрашивает.
  Future<void> initialize();

  /// Текущее разрешение, без диалога.
  Future<NotificationPermission> permission();

  /// Запрашивает разрешение системным диалогом (Android 13+). Если диалог
  /// уже не показывается (дважды отказано), вернёт
  /// [NotificationPermission.denied] сразу: тогда помогает только
  /// [openSystemSettings].
  Future<NotificationPermission> requestPermission();

  /// Открывает системные настройки уведомлений приложения.
  Future<void> openSystemSettings();

  /// Заменяет все напоминания приложения на [at] (моменты в UTC, строго в
  /// будущем): сначала отменяет прежние, потом ставит новые. Пустой список
  /// просто отменяет. Расписание неточное: система может сдвинуть показ
  /// (Doze, экономия заряда).
  Future<void> replaceReminders(List<DateTime> at, ReminderTexts texts);

  /// Маршрут тапа по уведомлению, которым запущено приложение (холодный
  /// старт). Отдаётся один раз, потом `null`.
  Future<String?> takeLaunchRoute();

  /// Маршруты тапов по уведомлениям, пока приложение запущено.
  Stream<String> get taps;
}
