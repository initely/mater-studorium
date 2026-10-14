import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_session_notifier.dart';
import '../sync/data/sync_providers.dart';
import 'supabase_init.dart';

/// Запускает работу с бэкендом, как только Supabase готов: анонимный вход
/// (без сети повторяется в фоне) и синхронизацию прогресса (T17). Срабатывает
/// и при повторной инициализации по кнопке «Повторить» (POLISH п. 3), а не
/// только на старте приложения. Читается один раз из `main`.
final backendBootstrapProvider = Provider<void>((ref) {
  var started = false;
  void start(SupabaseStatus status) {
    if (started || status != SupabaseStatus.ready) return;
    started = true;
    ref.read(authSessionProvider);
    ref.read(syncBootstrapProvider);
  }

  ref.listen(supabaseStatusProvider, (_, next) => start(next));
  start(ref.read(supabaseStatusProvider));
});
