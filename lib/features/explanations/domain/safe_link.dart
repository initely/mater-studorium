/// Разбирает [url] как ссылку, которую можно открыть во внешнем браузере:
/// только `https` с непустым хостом и без логина и пароля в адресе (ревью
/// T10, ТЗ AC6.2). Всё остальное (`http`, `javascript:`, `file:`,
/// относительные и битые адреса) — `null`: такую ссылку приложение не
/// открывает, а показывает текстом.
Uri? parseSafeLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  if (uri.scheme != 'https') return null;
  // Пробелы и прочие запрещённые символы в хосте Uri кодирует в `%XX`.
  if (uri.host.isEmpty || uri.host.contains('%')) return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}
