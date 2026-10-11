import 'dart:async';

import 'package:mater_studorium/features/catalog/domain/catalog_repository.dart';
import 'package:mater_studorium/features/catalog/domain/local_deck.dart';
import 'package:mater_studorium/features/catalog/domain/remote_deck.dart';

import 'db_fixtures.dart' show t0;

RemoteDeck remoteDeck(String id, {int version = 1, int items = 20}) =>
    RemoteDeck(
      id: id,
      title: 'Колода $id',
      topic: 'infosec',
      lang: 'ru',
      version: version,
      itemCount: items,
      storagePath: '$id/v$version.json',
    );

LocalDeck localDeck(String id, {int version = 1}) => LocalDeck(
  id: id,
  version: version,
  title: 'Колода $id',
  topic: 'infosec',
  lang: 'ru',
  downloadedAt: t0,
);

/// Репозиторий, которым тест управляет вручную.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    this.remote = const [],
    List<LocalDeck> local = const [],
  }) : _local = [...local];

  List<RemoteDeck> remote;
  Object? listError;
  Object? downloadError;
  Completer<void>? downloadGate;
  final downloads = <String>[];
  var listCalls = 0;

  final List<LocalDeck> _local;
  late final _controller = StreamController<List<LocalDeck>>.broadcast(
    onListen: () {},
  );

  @override
  Future<List<RemoteDeck>> list() async {
    listCalls++;
    if (listError != null) throw listError!;
    return remote;
  }

  @override
  Stream<List<LocalDeck>> watchDownloaded() async* {
    yield [..._local];
    yield* _controller.stream;
  }

  @override
  Future<LocalDeck> download(String deckId) async {
    downloads.add(deckId);
    await downloadGate?.future;
    if (downloadError != null) throw downloadError!;
    final deck = remote.firstWhere((d) => d.id == deckId);
    _local
      ..removeWhere((d) => d.id == deckId)
      ..add(localDeck(deckId, version: deck.version));
    _controller.add([..._local]);
    return _local.last;
  }
}
