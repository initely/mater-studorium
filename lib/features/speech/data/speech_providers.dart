import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/speech_service.dart';
import 'platform_app_settings_opener.dart';
import 'speech_to_text_service.dart';

/// Диктовка на устройстве. Один сервис на приложение (плагин держит
/// синглтон распознавателя). В тестах подменяется fake.
final speechServiceProvider = Provider<SpeechService>(
  (ref) => SpeechToTextService(),
);

final appSettingsOpenerProvider = Provider<AppSettingsOpener>(
  (ref) => const PlatformAppSettingsOpener(),
);
