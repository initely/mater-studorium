import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/supabase/supabase_init.dart';
import 'package:mater_studorium/features/auth/data/account_providers.dart';
import 'package:mater_studorium/features/auth/presentation/auth_session_notifier.dart';
import 'package:mater_studorium/features/catalog/data/catalog_providers.dart';
import 'package:mater_studorium/features/catalog/data/deck_remote_source.dart';
import 'package:mater_studorium/features/catalog/domain/remote_deck.dart';

import 'app_fixtures.dart';

/// Статус Supabase «готов» без настоящей инициализации.
class ReadyStatus extends SupabaseStatusNotifier {
  @override
  SupabaseStatus build() => SupabaseStatus.ready;
}

/// Управляемый анонимный вход.
class FakeAuthSession extends AuthSessionNotifier {
  FakeAuthSession([this.initial = AuthSessionStatus.signingIn]);

  final AuthSessionStatus initial;

  @override
  AuthSessionStatus build() => initial;

  void set(AuthSessionStatus status) => state = status;
}

/// Каталог, который, как настоящий сервер, отказывает без анонимной сессии.
class SessionGatedRemote implements DeckRemoteSource {
  SessionGatedRemote(this.inner);

  final SampleRemote inner;
  var signedIn = false;
  var fetches = 0;

  @override
  Future<List<RemoteDeck>> fetchDecks() async {
    fetches++;
    if (!signedIn) throw const NetworkError('нет сессии');
    return inner.fetchDecks();
  }

  @override
  Future<RemoteDeck?> fetchDeck(String deckId) => inner.fetchDeck(deckId);

  @override
  Future<Uint8List> downloadDeckFile(String storagePath) =>
      inner.downloadDeckFile(storagePath);
}

/// Бэкенд настроен, инициализатор подменён; [onInit] решает, удалась ли
/// попытка (бросает — не удалась).
List<Override> fakeBackend({
  required Future<void> Function() onInit,
  bool configured = true,
}) => [
  backendConfiguredProvider.overrideWithValue(configured),
  supabaseInitializerProvider.overrideWithValue(onInit),
];

/// Каталог, который зависит от статуса, как настоящий: пока Supabase не готов
/// — «нет сети», после инициализации — [remote].
Override remoteByStatus(DeckRemoteSource remote) =>
    deckRemoteSourceProvider.overrideWith(
      (ref) => ref.watch(supabaseStatusProvider) == SupabaseStatus.ready
          ? remote
          : const UnavailableDeckRemoteSource(),
    );
