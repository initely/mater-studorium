/// Ключи адреса возврата, которыми gotrue принимает готовую сессию (implicit
/// flow). Наш вход идёт по PKCE, и возврат от Google приносит только `code`
/// (или ошибку), поэтому такие ключи в адресе возврата означают подделку:
/// ссылка, подсунутая человеку, подменила бы его сессию сессией атакующего
/// (ревью безопасности T21, B2).
const kForbiddenOAuthReturnKeys = [
  'access_token',
  'refresh_token',
  'provider_token',
  'provider_refresh_token',
];

/// Ключи, по которым адрес считается возвратом после входа: код обмена (PKCE)
/// или ошибка.
const kOAuthReturnKeys = ['code', 'error', 'error_code', 'error_description'];

/// Можно ли обработать входящий адрес как возврат из браузера после входа
/// через Google (предикат разбора входящих адресов в клиенте Supabase).
///
/// Принимает адрес, только если все условия выполнены:
/// 1. схема, хост, порт и путь совпадают с [expected] (адресом, который мы сами
///    передали в `redirect_to`: Android — deep link, web — адрес приложения);
/// 2. ни в query, ни во фрагменте нет `access_token`, `refresh_token`,
///    `provider_token`, `provider_refresh_token` (ни явно, ни в закодированном
///    виде): готовые токены сторонней сессии не принимаются никогда;
/// 3. есть `code` или `error`, `error_code`, `error_description`.
///
/// Чужой `?code=` безопасен: у приложения нет соответствующего
/// `code_verifier`, обмен не состоится. Любая ошибка разбора — отказ.
bool isOAuthReturnUri(Uri uri, {required Uri expected}) {
  try {
    if (uri.scheme.toLowerCase() != expected.scheme.toLowerCase() ||
        uri.host.toLowerCase() != expected.host.toLowerCase() ||
        uri.port != expected.port ||
        _normalizedPath(uri.path) != _normalizedPath(expected.path)) {
      return false;
    }
    final raw = uri.toString().toLowerCase();
    if (kForbiddenOAuthReturnKeys.any(raw.contains)) return false;
    final keys = <String>{
      ...uri.queryParameters.keys,
      ..._fragmentKeys(uri.fragment),
    }.map((k) => k.toLowerCase()).toSet();
    if (kForbiddenOAuthReturnKeys.any(keys.contains)) return false;
    return kOAuthReturnKeys.any(keys.contains);
  } on FormatException {
    return false;
  } on ArgumentError {
    return false;
  }
}

String _normalizedPath(String path) =>
    path.endsWith('/') ? path.substring(0, path.length - 1) : path;

/// Ключи фрагмента вида `a=b&c=d`. Фрагмент-маршрут (`/settings`) и пустой
/// фрагмент ключей не дают; gotrue читает фрагмент так же, как query.
Iterable<String> _fragmentKeys(String fragment) {
  if (fragment.isEmpty) return const [];
  return Uri.splitQueryString(fragment).keys;
}
