// Сборка приложения на настоящей БД в памяти для тестов экранов T18:
// онбординг, главный, колода, настройки.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/db/database_providers.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/utils/clock.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/data/catalog_providers.dart';
import 'package:mater_studorium/features/catalog/data/deck_remote_source.dart';
import 'package:mater_studorium/features/catalog/data/drift_catalog_repository.dart';
import 'package:mater_studorium/features/catalog/domain/catalog_repository.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/deck_parser.dart';
import 'package:mater_studorium/features/catalog/domain/remote_deck.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';

import 'db_fixtures.dart';
import 'deck_fixtures.dart';
import 'session_db_fixtures.dart';

/// Сервер с одной колодой `sample` (файл `content/decks/sample.json`).
class SampleRemote implements DeckRemoteSource {
  SampleRemote({this.version = 1});

  int version;

  /// Если задано, любой запрос падает этой ошибкой (нет сети).
  AppError? fail;

  RemoteDeck get _deck {
    final json = readJsonFile(sampleDeckPath);
    return RemoteDeck(
      id: 'sample',
      title: json['title'] as String,
      topic: json['topic'] as String,
      lang: json['lang'] as String,
      version: version,
      itemCount: (json['items'] as List<dynamic>).length,
      storagePath: 'sample/v$version.json',
    );
  }

  @override
  Future<List<RemoteDeck>> fetchDecks() async =>
      fail == null ? [_deck] : throw fail!;

  @override
  Future<RemoteDeck?> fetchDeck(String deckId) async =>
      fail != null ? throw fail! : (deckId == 'sample' ? _deck : null);

  @override
  Future<Uint8List> downloadDeckFile(String storagePath) async {
    if (fail != null) throw fail!;
    // Версия внутри файла должна совпадать с каталогом.
    final json = readJsonFile(sampleDeckPath)..['version'] = version;
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }
}

/// Пользователь, часы и БД — общие для тестов T18.
List<Override> appOverrides(
  AppDatabase db, {
  DateTime? now,
  DeckRemoteSource? remote,

  /// Подмена каталога целиком (тогда `remote` не нужен).
  CatalogRepository? catalog,
}) => [
  appDatabaseProvider.overrideWithValue(db),
  sessionUserIdProvider.overrideWithValue(() => sessionUser),
  clockProvider.overrideWithValue(() => now ?? t0),
  randomProvider.overrideWithValue(math.Random(1)),
  uuidGeneratorProvider.overrideWithValue(() => 'log-${_ids++}'),
  if (remote != null) deckRemoteSourceProvider.overrideWithValue(remote),
  // Разбор колоды без изолята: в тестах `compute` не дожидается FakeAsync.
  if (catalog != null)
    catalogRepositoryProvider.overrideWithValue(catalog)
  else
    catalogRepositoryProvider.overrideWith(
      (ref) => DriftCatalogRepository(
        remote: ref.watch(deckRemoteSourceProvider),
        decks: ref.watch(decksDaoProvider),
        clock: ref.watch(clockProvider),
        parser: (bytes) async => parseDeckBytes(bytes),
      ),
    ),
];

var _ids = 0;

/// Онбординг уже пройден (флаг в `app_settings`).
Future<void> markOnboarded(AppDatabase db) =>
    db.settingsDao.write('onboarding_done', '1');

/// Колода `sample.json` записана в БД как скачанная.
Future<void> installSample(AppDatabase db) => db.decksDao.replaceDeck(
  Deck.fromJson(readJsonFile(sampleDeckPath)),
  downloadedAt: t0,
);
