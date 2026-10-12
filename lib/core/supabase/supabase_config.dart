import 'package:flutter/foundation.dart';

/// Параметры подключения к Supabase из `--dart-define` (см. `.env.example`).
/// В клиенте только URL и anon key; секреты (service role и т. п.) сюда не попадают.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Схема и хост deep link, на который GoTrue возвращает Android после
  /// входа через Google. Совпадают с `intent-filter` в `AndroidManifest.xml`
  /// и со списком `additional_redirect_urls` в `supabase/config.toml` (T21,
  /// ADR-34).
  static const androidRedirectUrl =
      'app.materstudorium.mater-studorium://login-callback';

  /// Куда возвращать пользователя после Google. На web это адрес самого
  /// приложения без запроса и фрагмента (его нужно внести в список
  /// разрешённых адресов Supabase, README), на Android deep link.
  static String get oauthRedirectUrl {
    if (!kIsWeb) return androidRedirectUrl;
    final base = Uri.base;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
    ).toString();
  }
}
