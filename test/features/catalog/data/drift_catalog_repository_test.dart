import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/db/decks_dao.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/data/deck_remote_source.dart';
import 'package:mater_studorium/features/catalog/data/drift_catalog_repository.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/remote_deck.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/deck_fixtures.dart';

const _v1Path = 'test/fixtures/decks/catalog_v1.json';
const _v2Path = 'test/fixtures/decks/catalog_v2.json';

/// Сервер в памяти: каталог и файлы по пути.
class _FakeRemote implements DeckRemoteSource {
  final decks = <String, RemoteDeck>{};
  final files = <String, Uint8List>{};
  AppError? failList;
  AppError? failFile;
  var fileDownloads = 0;

  /// Публикует колоду из файла-фикстуры (или из своих байт).
  void publish(String id, int version, {Uint8List? bytes, String? path}) {
    final storagePath = '$id/v$version.json';
    final deckJson = path == null ? null : readJsonFile(path);
    decks[id] = RemoteDeck(
      id: id,
      title: (deckJson?['title'] as String?) ?? id,
      topic: 'infosec',
      lang: 'ru',
      version: version,
      itemCount: (deckJson?['items'] as List<dynamic>?)?.length ?? 0,
      storagePath: storagePath,
    );
    files[storagePath] =
        bytes ?? Uint8List.fromList(File(path!).readAsBytesSync());
  }

  @override
  Future<List<RemoteDeck>> fetchDecks() async {
    if (failList != null) throw failList!;
    return decks.values.toList();
  }

  @override
  Future<RemoteDeck?> fetchDeck(String deckId) async {
    if (failList != null) throw failList!;
    return decks[deckId];
  }

  @override
  Future<Uint8List> downloadDeckFile(String storagePath) async {
    fileDownloads++;
    if (failFile != null) throw failFile!;
    return files[storagePath] ?? (throw DeckNotFoundError(storagePath));
  }
}

/// DAO, у которого запись колоды падает сырым исключением.
class _BrokenDao extends DecksDao {
  _BrokenDao(super.db);

  @override
  Future<void> replaceDeck(Deck deck, {required DateTime downloadedAt}) =>
      Future.error(StateError('диск полон'));
}

Uint8List _bytes(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  late AppDatabase db;
  late _FakeRemote remote;
  late DriftCatalogRepository repo;
  var now = t0;

  setUp(() {
    db = memoryDb();
    remote = _FakeRemote();
    now = t0;
    // Реальный разбор в изоляте (compute), как в приложении.
    repo = DriftCatalogRepository(
      remote: remote,
      decks: db.decksDao,
      clock: () => now,
    );
  });

  group('AC2.1: распаковка', () {
    test('колода скачивается и распаковывается в локальную БД', () async {
      remote.publish('catalog-fixture', 1, path: _v1Path);

      final local = await repo.download('catalog-fixture');

      expect(local.version, 1);
      expect(local.downloadedAt, t0);
      expect(
        (await db.select(db.items).get()).map((i) => i.id),
        unorderedEquals(['c.a', 'c.b', 'c.c']),
      );
      expect(await db.select(db.questions).get(), hasLength(6));
      final item = await db.decksDao.getItem('c.a');
      expect(item!.retired, isFalse);
      expect(item.refs, isNotEmpty);
    });

    test(
      'колода на 500 знаний: скачивание и распаковка быстрее 3 секунд',
      () async {
        // Тест на машине разработки; на среднем Android число другое (ручная проверка).
        final template = readJsonFile(goodDeckPath);
        final first = jsonEncode((template['items'] as List<dynamic>).first);
        final big = readJsonFile(goodDeckPath)
          ..['id'] = 'big'
          ..['version'] = 1
          ..['items'] = [
            for (var i = 0; i < 500; i++)
              jsonDecode(first.replaceAll('t.a', 'big.$i')),
          ];
        remote.publish('big', 1, bytes: _bytes(big));

        final timer = Stopwatch()..start();
        await repo.download('big');
        timer.stop();

        expect(await db.select(db.items).get(), hasLength(500));
        expect(await db.select(db.questions).get(), hasLength(1000));
        expect(
          timer.elapsed,
          lessThan(const Duration(seconds: 3)),
          reason: 'распаковка 500 знаний заняла ${timer.elapsed}',
        );
      },
    );

    test('локальная версия не ниже серверной: файл не качается', () async {
      remote.publish('catalog-fixture', 1, path: _v1Path);
      await repo.download('catalog-fixture');
      remote.fileDownloads = 0;

      final local = await repo.download('catalog-fixture');

      expect(local.version, 1);
      expect(remote.fileDownloads, 0);
    });

    test('списки: list() и watchDownloaded()', () async {
      remote.publish('catalog-fixture', 1, path: _v1Path);
      expect((await repo.list()).single.id, 'catalog-fixture');

      final emissions = <List<String>>[];
      final sub = repo.watchDownloaded().listen(
        (decks) => emissions.add([for (final d in decks) d.id]),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await repo.download('catalog-fixture');
      await pumpEventQueue();

      expect(emissions.first, isEmpty);
      expect(emissions.last, ['catalog-fixture']);
    });
  });

  group('AC2.2: обновление версии', () {
    test('прогресс сохраняется, исчезнувшие знания retired', () async {
      remote.publish('catalog-fixture', 1, path: _v1Path);
      await repo.download('catalog-fixture');
      // Прогресс пользователя: c.a (изменится), c.b (удалят), c.c (не тронут).
      for (final id in ['c.a', 'c.b', 'c.c']) {
        await db.reviewDao.recordReview(
          userId: 'u1',
          log: logFor(id, id: 'log-$id'),
          state: stateFor(id, deckId: 'catalog-fixture', due: t0),
        );
      }
      final before = {
        for (final id in ['c.a', 'c.b', 'c.c'])
          id: await db.reviewDao.getState('u1', id),
      };

      remote.publish('catalog-fixture', 2, path: _v2Path);
      now = t0.add(const Duration(days: 3));
      final local = await repo.download('catalog-fixture');

      expect(local.version, 2);
      expect(local.downloadedAt, now);
      // Состояние повторений не изменилось ни у одного знания, в том числе у удалённого.
      for (final id in ['c.a', 'c.b', 'c.c']) {
        expect(await db.reviewDao.getState('u1', id), before[id], reason: id);
      }
      expect(await db.select(db.reviewLogs).get(), hasLength(3));
      // Изменённое знание обновлено, у него убран один вопрос.
      expect(
        (await db.decksDao.getItem('c.a'))!.fact,
        contains('второй версии'),
      );
      expect((await db.decksDao.visibleQuestions('c.a')).map((q) => q.id), [
        'c.a.q1',
      ]);
      // Неизменённое осталось активным, новое добавлено.
      expect((await db.decksDao.getItem('c.c'))!.retired, isFalse);
      expect((await db.decksDao.getItem('c.d'))!.retired, isFalse);
      // Удалённое из колоды знание помечено retired, но не стёрто.
      final removed = await db.decksDao.getItem('c.b');
      expect(removed!.retired, isTrue);
      expect(await db.decksDao.getQuestion('c.b.q1'), isNotNull);
    });
  });

  group('AC2.3: повреждённый файл не ломает приложение', () {
    Future<void> publishV1AndDownload() async {
      remote.publish('catalog-fixture', 1, path: _v1Path);
      await repo.download('catalog-fixture');
    }

    Future<void> expectOldVersionIntact() async {
      expect((await db.decksDao.getDeck('catalog-fixture'))!.version, 1);
      expect(
        (await db.select(db.items).get()).map((i) => i.id),
        unorderedEquals(['c.a', 'c.b', 'c.c']),
      );
      expect(await db.select(db.questions).get(), hasLength(6));
      expect((await db.decksDao.getItem('c.b'))!.retired, isFalse);
    }

    final v2 = readJsonFile(_v2Path);
    final corrupted = <String, Uint8List>{
      'не JSON': Uint8List.fromList(
        utf8.encode('{"schema_version": 1, "id": '),
      ),
      'не UTF-8': Uint8List.fromList([0xff, 0xfe, 0x7b, 0x7d]),
      'корень — массив': _bytes([1, 2, 3]),
      'нет обязательного поля': _bytes(
        Map<String, dynamic>.of(v2)..remove('title'),
      ),
      'ломает семантику (дубль id знания)': _bytes(
        Map<String, dynamic>.of(v2)
          ..['items'] = [
            for (final i in v2['items'] as List<dynamic>) i,
            (v2['items'] as List<dynamic>).first,
          ],
      ),
      'пустой файл': Uint8List(0),
    };

    corrupted.forEach((name, bytes) {
      test('$name: DeckFormatError, остаётся старая версия', () async {
        await publishV1AndDownload();
        remote.publish('catalog-fixture', 2, bytes: bytes);

        await expectLater(
          repo.download('catalog-fixture'),
          throwsA(isA<DeckFormatError>()),
        );

        await expectOldVersionIntact();
      });
    });

    test('первая загрузка повреждённого файла: колоды нет, БД пуста', () async {
      remote.publish(
        'catalog-fixture',
        1,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      await expectLater(
        repo.download('catalog-fixture'),
        throwsA(isA<DeckFormatError>()),
      );

      expect(await db.select(db.decks).get(), isEmpty);
      expect(await db.select(db.items).get(), isEmpty);
    });

    test(
      'schema_version выше поддерживаемой: DeckSchemaTooNewError (ADR-19)',
      () async {
        await publishV1AndDownload();
        final future = Map<String, dynamic>.of(v2)..['schema_version'] = 99;
        remote.publish('catalog-fixture', 2, bytes: _bytes(future));

        await expectLater(
          repo.download('catalog-fixture'),
          throwsA(
            isA<DeckSchemaTooNewError>().having(
              (e) => e.schemaVersion,
              'schemaVersion',
              99,
            ),
          ),
        );

        await expectOldVersionIntact();
      },
    );

    test('файл другой колоды или версии: DeckFormatError', () async {
      await publishV1AndDownload();
      // В каталоге v2, а внутри файла v1.
      remote.publish('catalog-fixture', 2, path: _v1Path);
      await expectLater(
        repo.download('catalog-fixture'),
        throwsA(isA<DeckFormatError>()),
      );
      // В каталоге одна колода, а в файле другая.
      remote.publish('another', 1, path: _v1Path);
      await expectLater(
        repo.download('another'),
        throwsA(isA<DeckFormatError>()),
      );
      await expectOldVersionIntact();
    });
  });

  group('прочие ошибки', () {
    test(
      'коллизия item_id: ItemIdCollisionError, ничего не записано',
      () async {
        remote.publish('catalog-fixture', 1, path: _v1Path);
        await repo.download('catalog-fixture');
        final other = readJsonFile(_v2Path)
          ..['id'] = 'other'
          ..['version'] = 1; // знания c.a, c.c, c.d: c.a уже в catalog-fixture
        remote.publish('other', 1, bytes: _bytes(other));

        await expectLater(
          repo.download('other'),
          throwsA(
            isA<ItemIdCollisionError>().having(
              (e) => e.otherDeckId,
              'other',
              'catalog-fixture',
            ),
          ),
        );

        expect(await db.decksDao.getDeck('other'), isNull);
        expect(await db.decksDao.getItem('c.d'), isNull);
      },
    );

    test(
      'нет сети: NetworkError из сервера доходит как есть, БД не тронута',
      () async {
        remote.failList = const NetworkError('нет сети');
        await expectLater(repo.list(), throwsA(isA<NetworkError>()));
        await expectLater(repo.download('x'), throwsA(isA<NetworkError>()));
        expect(await db.select(db.decks).get(), isEmpty);
      },
    );

    test(
      'сеть пропала при загрузке файла: NetworkError, старая версия на месте',
      () async {
        remote.publish('catalog-fixture', 1, path: _v1Path);
        await repo.download('catalog-fixture');
        remote.publish('catalog-fixture', 2, path: _v2Path);
        remote.failFile = const NetworkError('оборвалось');

        await expectLater(
          repo.download('catalog-fixture'),
          throwsA(isA<NetworkError>()),
        );

        expect((await db.decksDao.getDeck('catalog-fixture'))!.version, 1);
      },
    );

    test('колоды нет в каталоге: DeckNotFoundError', () async {
      await expectLater(
        repo.download('нет-такой'),
        throwsA(isA<DeckNotFoundError>()),
      );
    });

    test('сбой записи в БД: UnexpectedError, а не исключение drift', () async {
      remote.publish('catalog-fixture', 1, path: _v1Path);
      final broken = DriftCatalogRepository(
        remote: remote,
        decks: _BrokenDao(db),
        clock: () => now,
      );

      await expectLater(
        broken.download('catalog-fixture'),
        throwsA(isA<UnexpectedError>()),
      );
    });
  });
}
