// Адрес возврата Android: допустимая схема (RFC 3986) и согласованность
// кода, манифеста и конфига Supabase (ревью безопасности T21, B1).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/supabase/supabase_config.dart';

void main() {
  final uri = Uri.parse(SupabaseConfig.androidRedirectUrl);

  test('адрес возврата разбирается Dart без ошибок', () {
    expect(() => Uri.parse(SupabaseConfig.androidRedirectUrl), returnsNormally);
    expect(uri.host, 'login-callback');
    expect(uri.hasAbsolutePath || uri.path.isEmpty, isTrue);
  });

  test('схема допустима по RFC 3986 (без «_»), строчная', () {
    expect(uri.scheme, matches(RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*$')));
    expect(uri.scheme, isNot(contains('_')));
    expect(uri.scheme, uri.scheme.toLowerCase());
    // Схема не должна быть голым applicationId: в нём есть «_».
    expect(uri.scheme, isNot('app.materstudorium.mater_studorium'));
  });

  test('схема и хост в intent-filter манифеста совпадают с кодом', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final data = RegExp(
      r'<data\s+android:scheme="([^"]+)"\s+android:host="([^"]+)"\s*/>',
    ).allMatches(manifest).toList();

    expect(data, hasLength(1));
    expect(data.single.group(1), uri.scheme);
    expect(data.single.group(2), uri.host);
  });

  test('additional_redirect_urls в config.toml содержит адрес возврата', () {
    final config = File('supabase/config.toml').readAsStringSync();
    final block = RegExp(
      r'additional_redirect_urls\s*=\s*\[(.*?)\]',
      dotAll: true,
    ).firstMatch(config)!.group(1)!;
    final urls = RegExp(r'"([^"]+)"')
        .allMatches(block)
        .map((m) => m.group(1)!)
        .toList();

    expect(urls, contains(SupabaseConfig.androidRedirectUrl));
    for (final u in urls) {
      // Каждый адрес в списке должен разбираться и Dart, и (по виду схемы)
      // Go: схема без «_».
      expect(
        () => Uri.parse(u.replaceAll('**', 'x')),
        returnsNormally,
        reason: u,
      );
      expect(
        Uri.parse(u.replaceAll('**', 'x')).scheme,
        matches(RegExp(r'^[a-z][a-z0-9+.-]*$')),
        reason: u,
      );
    }
  });

  test('в конфиге и манифесте нет прежнего недопустимого адреса', () {
    for (final path in [
      'supabase/config.toml',
      'android/app/src/main/AndroidManifest.xml',
      'lib/core/supabase/supabase_config.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('materstudorium.mater_studorium://')),
        reason: path,
      );
    }
  });

  test('enable_manual_linking и enable_confirmations в конфиге (S2)', () {
    final config = File('supabase/config.toml').readAsStringSync();
    expect(config, contains('enable_manual_linking = true'));
    final email = config.substring(config.indexOf('[auth.email]'));
    expect(
      RegExp(
        r'^enable_confirmations = true$',
        multiLine: true,
      ).firstMatch(email.substring(0, email.indexOf('[auth.sms]'))),
      isNotNull,
    );
  });
}
