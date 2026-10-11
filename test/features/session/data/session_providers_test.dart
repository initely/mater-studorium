import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database_providers.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/supabase/supabase_init.dart';
import 'package:mater_studorium/features/session/data/drift_session_repository.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';
import 'package:mater_studorium/features/session/domain/session_queue_builder.dart';
import 'package:mater_studorium/features/session/domain/session_settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/db_fixtures.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

void main() {
  late MockGoTrueClient auth;
  late ProviderContainer container;

  setUp(() {
    auth = MockGoTrueClient();
    final client = MockSupabaseClient();
    when(() => client.auth).thenReturn(auth);
    container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        appDatabaseProvider.overrideWithValue(memoryDb()),
      ],
    );
    addTearDown(container.dispose);
  });

  group('sessionUserIdProvider', () {
    test('отдаёт id пользователя из сессии Supabase', () {
      final user = MockUser();
      when(() => user.id).thenReturn('user-42');
      when(() => auth.currentUser).thenReturn(user);

      expect(container.read(sessionUserIdProvider)(), 'user-42');
    });

    test('без сессии — AuthError, а не null', () {
      when(() => auth.currentUser).thenReturn(null);

      expect(container.read(sessionUserIdProvider), throwsA(isA<AuthError>()));
    });

    test('id берётся при каждом вызове: вход мог завершиться позже', () {
      final user = MockUser();
      when(() => user.id).thenReturn('late');
      when(() => auth.currentUser).thenReturn(null);
      final userId = container.read(sessionUserIdProvider);
      expect(userId, throwsA(isA<AuthError>()));

      when(() => auth.currentUser).thenReturn(user);

      expect(userId(), 'late');
    });
  });

  test('deviceUtcOffset совпадает со смещением локальной зоны платформы', () {
    for (final utc in [
      DateTime.utc(2026, 1, 15, 12),
      DateTime.utc(2026, 7, 15, 12),
    ]) {
      expect(deviceUtcOffset(utc), utc.toLocal().timeZoneOffset);
    }
    expect(container.read(utcOffsetProvider), same(deviceUtcOffset));
  });

  test('провайдеры собирают построитель из DAO, настроек по умолчанию', () {
    expect(
      container.read(sessionRepositoryProvider),
      isA<DriftSessionRepository>(),
    );
    expect(
      container.read(sessionQueueBuilderProvider),
      isA<SessionQueueBuilder>(),
    );
    final settings = container.read(sessionSettingsProvider);
    expect(settings.newPerDay, kDefaultNewPerDay);
    expect(settings.sessionSize, kDefaultSessionSize);
    expect(settings.deckIds, isNull);
  });

  test('SessionSettings: недопустимые значения отвергаются', () {
    expect(
      () => SessionSettings(sessionSize: 0),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => SessionSettings(newPerDay: -1),
      throwsA(isA<AssertionError>()),
    );
    expect(const SessionSettings(newPerDay: 0).newPerDay, 0);
  });
}
