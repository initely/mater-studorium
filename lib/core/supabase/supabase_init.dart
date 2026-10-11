import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Инициализирует Supabase из [SupabaseConfig]. Вызывать один раз из `main()`,
/// только если [SupabaseConfig.isConfigured].
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // publishableKey принимает и legacy anon key (JWT), и новый sb_publishable_...
    publishableKey: SupabaseConfig.anonKey,
  );
}

/// Клиент Supabase. Доступен только после [initSupabase]; в тестах подменяется.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
