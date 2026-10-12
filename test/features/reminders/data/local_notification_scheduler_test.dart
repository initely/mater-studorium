// Обёртка над flutter_local_notifications (T19): что именно уходит в плагин.
// Сам плагин и доставка уведомлений здесь не проверяются (нужно устройство).
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/reminders/data/local_notification_scheduler.dart';
import 'package:mater_studorium/features/reminders/domain/notification_scheduler.dart';
import 'package:mater_studorium/features/reminders/domain/reminder_texts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroid extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class _FakeSettings extends Fake implements InitializationSettings {}

class _FakeDetails extends Fake implements NotificationDetails {}

const _texts = ReminderTexts(
  title: 'Пора повторить',
  body: 'Пять минут',
  channelName: 'Канал',
  channelDescription: 'Описание',
);

void main() {
  late _MockPlugin plugin;
  late _MockAndroid android;
  late LocalNotificationScheduler scheduler;

  setUpAll(() {
    registerFallbackValue(_FakeSettings());
    registerFallbackValue(_FakeDetails());
    registerFallbackValue(tz.TZDateTime.utc(2026));
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
  });

  setUp(() {
    plugin = _MockPlugin();
    android = _MockAndroid();
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(android);
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    scheduler = LocalNotificationScheduler(plugin);
  });

  test('поддерживается; initialize один раз, при ошибке повторяется', () async {
    expect(scheduler.isSupported, isTrue);
    await scheduler.initialize();
    await scheduler.initialize();
    verify(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).called(1);
  });

  test('сбой платформы превращается в типизированную ошибку', () async {
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenThrow(PlatformException(code: 'boom'));
    await expectLater(scheduler.initialize(), throwsA(isA<UnexpectedError>()));
    // Следующая попытка идёт заново, а не отдаёт закешированную ошибку.
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    await scheduler.initialize();
  });

  test(
    'replaceReminders: сначала снимает 7 id, потом ставит неточные',
    () async {
      final at = [
        DateTime.utc(2026, 10, 12, 17),
        DateTime.utc(2026, 10, 13, 17),
      ];
      await scheduler.replaceReminders(at, _texts);

      verify(() => plugin.cancel(id: any(named: 'id'))).called(kReminderDays);
      final calls = verify(
        () => plugin.zonedSchedule(
          id: captureAny(named: 'id'),
          scheduledDate: captureAny(named: 'scheduledDate'),
          notificationDetails: captureAny(named: 'notificationDetails'),
          androidScheduleMode: captureAny(named: 'androidScheduleMode'),
          title: captureAny(named: 'title'),
          body: captureAny(named: 'body'),
          payload: captureAny(named: 'payload'),
        ),
      ).captured;
      // 2 вызова по 7 захваченных аргументов.
      expect(calls, hasLength(14));
      expect(calls[0], kReminderIdBase);
      expect(calls[7], kReminderIdBase + 1);
      final first = calls[1] as tz.TZDateTime;
      expect(first.toUtc(), at.first);
      expect(
        first.location,
        tz.UTC,
        reason: 'абсолютный момент без IANA-пояса',
      );
      expect(calls[3], AndroidScheduleMode.inexactAllowWhileIdle);
      expect(calls[4], 'Пора повторить');
      expect(calls[5], 'Пять минут');
      expect(calls[6], kReminderRoute);
      final details = (calls[2] as NotificationDetails).android!;
      expect(details.channelName, 'Канал');
    },
  );

  test('пустой список только отменяет', () async {
    await scheduler.replaceReminders(const [], _texts);
    verify(() => plugin.cancel(id: any(named: 'id'))).called(kReminderDays);
    verifyNever(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    );
  });

  test('разрешение: включено в системе или нет', () async {
    when(() => android.areNotificationsEnabled()).thenAnswer((_) async => true);
    expect(await scheduler.permission(), NotificationPermission.granted);
    when(() => android.areNotificationsEnabled())
        .thenAnswer((_) async => false);
    expect(await scheduler.permission(), NotificationPermission.denied);
    when(() => android.areNotificationsEnabled()).thenAnswer((_) async => null);
    expect(await scheduler.permission(), NotificationPermission.denied);
  });

  test('requestPermission: диалог, затем честная проверка состояния', () async {
    when(() => android.requestNotificationsPermission())
        .thenAnswer((_) async => false);
    when(() => android.areNotificationsEnabled())
        .thenAnswer((_) async => false);
    expect(await scheduler.requestPermission(), NotificationPermission.denied);
    verify(() => android.requestNotificationsPermission()).called(1);
  });

  test('запуск тапом по уведомлению: маршрут отдаётся один раз', () async {
    when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
      (_) async => const NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: kReminderRoute,
        ),
      ),
    );
    expect(await scheduler.takeLaunchRoute(), kReminderRoute);
    expect(await scheduler.takeLaunchRoute(), isNull);
  });

  test('обычный запуск: маршрута нет', () async {
    when(() => plugin.getNotificationAppLaunchDetails())
        .thenAnswer((_) async => const NotificationAppLaunchDetails(false));
    expect(await scheduler.takeLaunchRoute(), isNull);
  });

  test('тап при запущенном приложении попадает в поток', () async {
    late DidReceiveNotificationResponseCallback onTap;
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((invocation) async {
      onTap =
          invocation.namedArguments[#onDidReceiveNotificationResponse]
              as DidReceiveNotificationResponseCallback;
      return true;
    });
    await scheduler.initialize();
    final routes = <String>[];
    scheduler.taps.listen(routes.add);

    onTap(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: kReminderRoute,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(routes, [kReminderRoute]);
  });
}
