import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/speech_service.dart';

/// Канал с `MainActivity.kt`: открывает «О приложении» в настройках Android
/// (там включается разрешение на микрофон).
const MethodChannel kSystemChannel = MethodChannel('app.materstudorium/system');

class PlatformAppSettingsOpener implements AppSettingsOpener {
  const PlatformAppSettingsOpener();

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> openAppSettings() async {
    if (!isSupported) return;
    try {
      await kSystemChannel.invokeMethod<void>('openAppSettings');
    } on PlatformException {
      // Нет экрана настроек: пользователь откроет их сам.
    } on MissingPluginException {
      // Запуск без нативной части (тесты).
    }
  }
}
