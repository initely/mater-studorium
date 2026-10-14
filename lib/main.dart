import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/supabase/backend_bootstrap.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_init.dart';
import 'features/settings/presentation/settings_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  if (SupabaseConfig.isConfigured) {
    // Сбой инициализации не мешает запуску: бэкенд «недоступен» до повтора
    // (кнопка «Повторить» на экране колод), причина с трассой — в журнале.
    await container.read(supabaseStatusProvider.notifier).ensureInitialized();
    // Анонимный вход и синхронизация стартуют, как только Supabase готов
    // (сейчас или после повторной инициализации).
    container.read(backendBootstrapProvider);
  } else {
    debugPrint(
      'SUPABASE_URL / SUPABASE_ANON_KEY не заданы '
      '(--dart-define-from-file=.env.json): работаем без бэкенда.',
    );
  }
  // Роутер решает по флагу онбординга; читаем его до первого кадра, чтобы
  // не мигать промежуточным экраном. Ошибка чтения не мешает запуску.
  try {
    await container.read(settingsProvider.future);
  } catch (e) {
    debugPrint('Настройки не прочитаны: $e');
  }
  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
