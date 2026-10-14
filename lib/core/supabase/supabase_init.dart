import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/account_providers.dart';
import '../../features/auth/domain/oauth_return.dart';
import 'supabase_config.dart';

/// Адрес возврата после входа через Google. Разбирается один раз; если строка
/// не разбирается, предикат возврата просто никогда не срабатывает (вход через
/// Google не сломает запуск приложения).
Uri? _parsedRedirect() => Uri.tryParse(SupabaseConfig.oauthRedirectUrl);

/// Входящая ссылка — возврат из Google? Не бросает ни при каком адресе:
/// предикат вызывает `supabase_flutter` на каждую входящую ссылку (в том числе
/// на начальную после холодного запуска), и исключение из него уходило бы в
/// необработанную ошибку зоны.
bool isOAuthReturnUriSafe(Uri uri, {Uri? expected}) {
  try {
    final redirect = expected ?? _parsedRedirect();
    if (redirect == null) return false;
    return isOAuthReturnUri(uri, expected: redirect);
  } on Object catch (e, stack) {
    debugPrint('Входящая ссылка не разобрана: $e\n$stack');
    return false;
  }
}

/// Инициализирует Supabase из [SupabaseConfig]. Вызывается из `main()` и при
/// повторе, только если [SupabaseConfig.isConfigured]. Сам исключения не
/// гасит: это делает [SupabaseStatusNotifier.ensureInitialized].
Future<void> initSupabase() async {
  // Явная проверка вместо FormatException из глубины supabase_flutter
  // ("Scheme not starting with alphabetic character"): сразу видно, что не так.
  final url = Uri.tryParse(SupabaseConfig.url);
  if (url == null || !url.hasScheme || url.host.isEmpty) {
    throw const FormatException(
      'SUPABASE_URL не похож на адрес (нужен http(s)://хост)',
    );
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // publishableKey принимает и legacy anon key (JWT), и новый sb_publishable_...
    publishableKey: SupabaseConfig.anonKey,
    // Входящий адрес обрабатывается как возврат из Google, только если это наш
    // адрес возврата и в нём нет готовых токенов (ревью T21, B2): иначе ссылка
    // с чужими токенами подменила бы сессию человека.
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUriPredicate: isOAuthReturnUriSafe,
    ),
  );
}

/// Инициализирован ли `Supabase.instance`. Сам геттер `instance` в debug
/// падает assert-ом, а в release отдаёт неготовый объект, поэтому снаружи
/// спрашивать только так.
bool isSupabaseInitialized() {
  try {
    return Supabase.instance.isInitialized;
  } on Object {
    return false;
  }
}

enum SupabaseStatus {
  /// Не настроен или инициализация не удалась: всё, что идёт на сервер,
  /// отвечает `NetworkError`.
  unavailable,

  /// `Supabase.instance` готов.
  ready,
}

/// Как инициализировать Supabase; в тестах подменяется.
final supabaseInitializerProvider = Provider<Future<void> Function()>(
  (ref) => initSupabase,
);

/// Состояние бэкенда. Сбой инициализации не роняет приложение и не даёт
/// красного экрана: провайдеры, зависящие от клиента, получают `null` и
/// отвечают типизированной `NetworkError`. [ensureInitialized] можно звать
/// снова (кнопка «Повторить»): каждая новая попытка пробует инициализацию
/// заново.
class SupabaseStatusNotifier extends Notifier<SupabaseStatus> {
  Future<bool>? _inflight;

  /// Последняя ошибка инициализации (для диагностики, UI её не показывает).
  Object? lastError;

  @override
  SupabaseStatus build() =>
      ref.read(backendConfiguredProvider) && isSupabaseInitialized()
      ? SupabaseStatus.ready
      : SupabaseStatus.unavailable;

  /// `true` — Supabase готов. Без настройки (`SUPABASE_URL` не задан)
  /// инициализацию не пробует. Одновременные вызовы делят одну попытку.
  Future<bool> ensureInitialized() {
    if (state == SupabaseStatus.ready) return Future.value(true);
    if (!ref.read(backendConfiguredProvider)) return Future.value(false);
    return _inflight ??= _attempt().whenComplete(() => _inflight = null);
  }

  Future<bool> _attempt() async {
    try {
      await ref.read(supabaseInitializerProvider)();
      lastError = null;
    } on Object catch (e, stack) {
      lastError = e;
      // Стек нужен, чтобы найти источник плавающего FormatException (POLISH п. 3).
      debugPrint('Supabase не инициализирован: $e\n$stack');
      // Часть ошибок приходит уже после создания клиента (слушатель ссылок):
      // тогда клиент рабочий, и объявлять бэкенд недоступным незачем.
      if (!isSupabaseInitialized()) return false;
    }
    if (ref.mounted) state = SupabaseStatus.ready;
    return ref.mounted;
  }
}

final supabaseStatusProvider =
    NotifierProvider<SupabaseStatusNotifier, SupabaseStatus>(
      SupabaseStatusNotifier.new,
    );

/// Клиент Supabase; `null`, пока бэкенд недоступен (не настроен или
/// инициализация не удалась). В тестах подменяется.
final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => ref.watch(supabaseStatusProvider) == SupabaseStatus.ready
      ? Supabase.instance.client
      : null,
);
