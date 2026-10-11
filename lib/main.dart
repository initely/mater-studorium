import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_init.dart';
import 'features/auth/presentation/auth_session_notifier.dart';

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
  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
