// Интеграционный тест каталога против ЖИВОГО локального Supabase (T10).
// По умолчанию пропускается: ему нужен запущенный стек и три переменные окружения.
//
//   supabase start && supabase db reset
//   eval "$(supabase status -o env | sed 's/^/export /')"   # API_URL, ANON_KEY, SERVICE_ROLE_KEY
//   LIVE_SUPABASE_URL=$API_URL LIVE_SUPABASE_ANON_KEY=$ANON_KEY \
//   LIVE_SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY flutter test --tags live test/integration
//
// Тест создаёт и удаляет колоду catalog-fixture; чужие колоды не трогает.
// Ключ service role берётся только из окружения запуска и в репозиторий не попадает.
@Tags(['live'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/data/drift_catalog_repository.dart';
import 'package:mater_studorium/features/catalog/data/supabase_deck_remote_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../tools/import_deck.dart';
import '../helpers/db_fixtures.dart' show t0;

const _v1 = 'test/fixtures/decks/catalog_v1.json';
const _v2 = 'test/fixtures/decks/catalog_v2.json';
const _deckId = 'catalog-fixture';

String? _env(String name) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : value;
}

void main() {
  final url = _env('LIVE_SUPABASE_URL');
  final anonKey = _env('LIVE_SUPABASE_ANON_KEY');
  final serviceKey = _env('LIVE_SUPABASE_SERVICE_KEY');
  final skip = url == null || anonKey == null || serviceKey == null
      ? 'нужны LIVE_SUPABASE_URL, LIVE_SUPABASE_ANON_KEY, LIVE_SUPABASE_SERVICE_KEY '
            'и запущенный локальный Supabase'
      : false;

  late SupabaseClient user; // анонимный пользователь, как в приложении
  late SupabaseClient admin; // service role: подготовка и уборка
  late Directory tmp;
  late String envPath;

  Future<void> cleanup() async {
    await admin.from('decks').delete().eq('id', _deckId);
    await admin.storage.from('decks').remove([
      for (final v in [1, 2, 3]) '$_deckId/v$v.json',
    ]);
  }

  Future<int> import(String file) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runImportDeck(
      [file, '--env=$envPath'],
      out: out,
      err: err,
    );
    if (code != 0) fail('import_deck: код $code\n$out\n$err');
    return code;
  }

  setUp(() async {
    if (skip != false) return;
    tmp = Directory.systemTemp.createTempSync('catalog_live_');
    envPath = '${tmp.path}/.env';
    File(envPath).writeAsStringSync(
      'SUPABASE_URL=$url\nSUPABASE_SERVICE_ROLE_KEY=$serviceKey\n',
    );
    admin = SupabaseClient(url!, serviceKey!);
    user = SupabaseClient(url, anonKey!);
    await user.auth.signInAnonymously();
    await cleanup();
  });

  tearDown(() async {
    if (skip != false) return;
    await cleanup();
    await user.auth.signOut();
    await user.dispose();
    await admin.dispose();
    tmp.deleteSync(recursive: true);
  });

  test(
    'импорт → список → скачивание → обновление → повреждённая версия',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftCatalogRepository(
        remote: SupabaseDeckRemoteSource(user),
        decks: db.decksDao,
        clock: () => t0,
      );

      // Колоды ещё нет.
      expect((await repo.list()).where((d) => d.id == _deckId), isEmpty);

      // v1: импорт (с --release: фикстура approved) и скачивание.
      await import(_v1);
      final listed = (await repo.list()).singleWhere((d) => d.id == _deckId);
      expect((listed.version, listed.itemCount), (1, 3));
      expect(listed.storagePath, '$_deckId/v1.json');
      final local1 = await repo.download(_deckId);
      expect(local1.version, 1);
      expect(await db.select(db.items).get(), hasLength(3));
      expect(await db.select(db.questions).get(), hasLength(6));

      // v2: знание c.b удалено, c.d добавлено.
      await import(_v2);
      expect(
        (await repo.list()).singleWhere((d) => d.id == _deckId).version,
        2,
      );
      expect((await repo.download(_deckId)).version, 2);
      expect((await db.decksDao.getItem('c.b'))!.retired, isTrue);
      expect((await db.decksDao.getItem('c.d'))!.retired, isFalse);

      // Повреждённый файл v3 (строка каталога честная, файл битый).
      await admin.storage
          .from('decks')
          .uploadBinary(
            '$_deckId/v3.json',
            Uint8List.fromList('{"broken":'.codeUnits),
            fileOptions: const FileOptions(contentType: 'application/json'),
          );
      await admin
          .from('decks')
          .update({'version': 3, 'storage_path': '$_deckId/v3.json'})
          .eq('id', _deckId);
      await expectLater(
        repo.download(_deckId),
        throwsA(isA<DeckFormatError>()),
      );
      expect((await db.decksDao.getDeck(_deckId))!.version, 2);
      expect((await db.decksDao.getItem('c.d'))!.retired, isFalse);

      // Коллизия и повторный импорт той же версии отклоняются.
      final out = StringBuffer();
      final err = StringBuffer();
      expect(
        await runImportDeck([_v2, '--env=$envPath'], out: out, err: err),
        1,
        reason: 'версия 2 не больше текущей (3)',
      );
    },
    skip: skip,
  );

  test(
    'RLS на живом стеке: аноним читает, но не пишет; без входа ничего не видно',
    () async {
      await import(_v1);

      // Вошедший (анонимный) пользователь читает каталог и файл.
      expect(
        await user.from('decks').select('id').eq('id', _deckId),
        hasLength(1),
      );
      final bytes = await user.storage
          .from('decks')
          .download('$_deckId/v1.json');
      expect(bytes, isNotEmpty);

      // Но не пишет ни строку, ни файл, ни не меняет, ни не удаляет.
      await expectLater(
        user.from('decks').insert({
          'id': 'hack',
          'title': 't',
          'topic': 'k',
          'lang': 'ru',
          'version': 1,
          'storage_path': 'hack/v1.json',
          'item_count': 0,
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        user.from('decks').update({'title': 'Hacked'}).eq('id', _deckId),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        user.from('decks').delete().eq('id', _deckId),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        user.storage
            .from('decks')
            .uploadBinary('$_deckId/v9.json', Uint8List.fromList([123, 125])),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        user.storage
            .from('decks')
            .uploadBinary(
              '$_deckId/v1.json',
              Uint8List.fromList([123, 125]),
              fileOptions: const FileOptions(upsert: true),
            ),
        throwsA(isA<StorageException>()),
      );
      await user.storage.from('decks').remove(['$_deckId/v1.json']);
      // Файл на месте: удаление молча затронуло 0 объектов.
      expect(
        await user.storage.from('decks').download('$_deckId/v1.json'),
        isNotEmpty,
      );
      expect(
        (await admin.from('decks').select('title').eq('id', _deckId))
            .single['title'],
        isNot('Hacked'),
      );

      // Без входа (только anon-ключ) каталог и файлы недоступны.
      final guest = SupabaseClient(url!, anonKey!);
      addTearDown(guest.dispose);
      await expectLater(
        guest.from('decks').select(),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        guest.storage.from('decks').download('$_deckId/v1.json'),
        throwsA(isA<StorageException>()),
      );
      // Репозиторий без сессии отвечает «нужна сеть», а не падает.
      final repo = DriftCatalogRepository(
        remote: SupabaseDeckRemoteSource(guest),
        decks: AppDatabase(NativeDatabase.memory()).decksDao,
        clock: () => t0,
      );
      await expectLater(repo.list(), throwsA(isA<NetworkError>()));
    },
    skip: skip,
  );
}
