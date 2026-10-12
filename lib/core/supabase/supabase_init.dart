import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/oauth_return.dart';
import 'supabase_config.dart';

/// Инициализирует Supabase из [SupabaseConfig]. Вызывать один раз из `main()`,
/// только если [SupabaseConfig.isConfigured].
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // publishableKey принимает и legacy anon key (JWT), и новый sb_publishable_...
    publishableKey: SupabaseConfig.anonKey,
    // Входящий адрес обрабатывается как возврат из Google, только если это наш
    // адрес возврата и в нём нет готовых токенов (ревью T21, B2): иначе ссылка
    // с чужими токенами подменила бы сессию человека.
    authOptions: FlutterAuthClientOptions(
      detectSessionInUriPredicate: (uri) => isOAuthReturnUri(
        uri,
        expected: Uri.parse(SupabaseConfig.oauthRedirectUrl),
      ),
    ),
  );
}

/// Клиент Supabase. Доступен только после [initSupabase]; в тестах подменяется.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
