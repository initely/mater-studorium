import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../data/duel_providers.dart';
import '../domain/display_name.dart';

/// Имя, под которым пользователя увидит соперник (`profiles.display_name`).
/// Значение — `null`, пока имя не задано.
class DisplayNameNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.watch(duelRepositoryProvider).displayName();

  /// Сохраняет [input] в очищенном виде (`sanitizeDisplayName`); пустой ввод
  /// убирает имя. Ошибку отдаёт вызывающему, состояние при ней прежнее.
  /// Возвращает сохранённое значение.
  Future<String?> save(String input) async {
    final name = sanitizeDisplayName(input);
    try {
      await ref.read(duelRepositoryProvider).setDisplayName(name);
    } on AppError {
      rethrow;
    } catch (e) {
      throw UnexpectedError('Имя: неожиданная ошибка', cause: e);
    }
    if (ref.mounted) state = AsyncData(name);
    return name;
  }
}

final displayNameProvider =
    AsyncNotifierProvider.autoDispose<DisplayNameNotifier, String?>(
      DisplayNameNotifier.new,
    );
