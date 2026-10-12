import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_init.dart';
import 'features/auth/presentation/auth_session_notifier.dart';
import 'features/settings/presentation/settings_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  if (SupabaseConfig.isConfigured) {
    try {
      await initSupabase();
      // Анонимный вход; без сети повторяется в фоне, приложение открывается сразу.
      container.read(authSessionProvider);
    } catch (e) {
      debugPrint('Supabase не инициализирован: $e');
    }
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
