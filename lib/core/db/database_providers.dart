import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'decks_dao.dart';
import 'review_dao.dart';
import 'settings_dao.dart';

/// В тестах подменяется на `AppDatabase(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(db.close);
  return db;
});

final decksDaoProvider = Provider<DecksDao>(
  (ref) => ref.watch(appDatabaseProvider).decksDao,
);

final reviewDaoProvider = Provider<ReviewDao>(
  (ref) => ref.watch(appDatabaseProvider).reviewDao,
);

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao,
);
