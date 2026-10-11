import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_init.dart';
import '../../../core/utils/uuid.dart';
import '../domain/local_day.dart';
import '../domain/session_queue_builder.dart';
import '../domain/session_repository.dart';
import '../domain/session_settings.dart';
import 'drift_session_repository.dart';

/// Id текущего пользователя (`auth.uid`). Без сессии — [AuthError]; в
/// тестах подменяется. Данные в локальной БД привязаны к нему.
final sessionUserIdProvider = Provider<String Function()>((ref) {
  final auth = ref.watch(supabaseClientProvider).auth;
  return () {
    final user = auth.currentUser;
    if (user == null) throw const AuthError('нет сессии пользователя');
    return user.id;
  };
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => DriftSessionRepository(
    review: ref.watch(reviewDaoProvider),
    decks: ref.watch(decksDaoProvider),
    userId: ref.watch(sessionUserIdProvider),
  ),
);

/// Смещение пояса устройства от UTC в момент [utc], с учётом перехода на
/// летнее время.
Duration deviceUtcOffset(DateTime utc) =>
    DateTime.fromMicrosecondsSinceEpoch(utc.microsecondsSinceEpoch)
        .timeZoneOffset;

/// Пояс пользователя для границ «сегодня». Сейчас — пояс устройства
/// (ADR-24); когда `profiles.timezone` попадёт на клиент (настройки,
/// напоминания), здесь подставляется пояс из профиля.
final utcOffsetProvider = Provider<UtcOffsetAt>((ref) => deviceUtcOffset);

/// Настройки сессии. Пока значения по умолчанию; экран настроек (T18)
/// подменит провайдер значениями пользователя.
final sessionSettingsProvider = Provider<SessionSettings>(
  (ref) => const SessionSettings(),
);

final sessionQueueBuilderProvider = Provider<SessionQueueBuilder>(
  (ref) => SessionQueueBuilder(
    repository: ref.watch(sessionRepositoryProvider),
    random: ref.watch(randomProvider),
    utcOffsetAt: ref.watch(utcOffsetProvider),
  ),
);
