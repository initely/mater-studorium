/// Параметры подключения к Supabase из `--dart-define` (см. `.env.example`).
/// В клиенте только URL и anon key; секреты (service role и т. п.) сюда не попадают.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
