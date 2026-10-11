import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/db/database_providers.dart';

import '../../helpers/db_fixtures.dart';

void main() {
  test('провайдеры DAO берут БД из appDatabaseProvider', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container
        .read(decksDaoProvider)
        .replaceDeck(goodDeck(), downloadedAt: t0);
    final newItems = await container.read(reviewDaoProvider).newItems('u1');
    expect(newItems, hasLength(3));
  });
}
