import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_providers.dart';
import '../domain/user_settings.dart';

/// Настройки пользователя: читаются один раз при старте (`main` ждёт
/// `settingsProvider.future` до первого кадра, чтобы роутер знал, пройден ли
/// онбординг), дальше обновляются из сеттеров. Сеттер сначала пишет в
/// хранилище, потом меняет состояние: при ошибке записи (`LocalStorageError`)
/// состояние прежнее, ошибка уходит вызывающему.
class SettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> setOnboardingDone(bool done) async {
    await ref.read(settingsRepositoryProvider).setOnboardingDone(done);
    _update((s) => s.copyWith(onboardingDone: done));
  }

  Future<void> setNewPerDay(int value) async {
    final v = value.clamp(kMinNewPerDay, kMaxNewPerDay);
    await ref.read(settingsRepositoryProvider).setNewPerDay(v);
    _update((s) => s.copyWith(newPerDay: v));
  }

  Future<void> setSessionSize(int value) async {
    final v = value.clamp(kMinSessionSize, kMaxSessionSize);
    await ref.read(settingsRepositoryProvider).setSessionSize(v);
    _update((s) => s.copyWith(sessionSize: v));
  }

  void _update(UserSettings Function(UserSettings) change) {
    if (!ref.mounted) return;
    // До загрузки значение не определено: меняем умолчания (запись уже в БД,
    // следующий запуск прочитает её).
    state = AsyncData(change(state.value ?? const UserSettings()));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);
