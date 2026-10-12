import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Открывает [uri] во внешнем приложении или браузере. `true` — открылось.
/// Вызывающий уже проверил адрес (`parseSafeLink`), здесь проверок нет.
typedef LinkLauncher = Future<bool> Function(Uri uri);

/// Системный запуск через `url_launcher` (Android, web: новая вкладка).
/// В тестах подменяется фейком: настоящие плагины в `flutter test` не
/// работают.
final linkLauncherProvider = Provider<LinkLauncher>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
