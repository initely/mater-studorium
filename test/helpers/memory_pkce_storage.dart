import 'package:supabase_flutter/supabase_flutter.dart';

/// Хранилище PKCE-проверочного кода в памяти (в приложении его даёт
/// supabase_flutter через shared_preferences).
class MemoryPkceStorage extends GotrueAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}
