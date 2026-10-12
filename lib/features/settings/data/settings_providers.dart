import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../domain/settings_repository.dart';
import 'drift_settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(settingsDaoProvider)),
);
