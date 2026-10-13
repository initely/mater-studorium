import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/check_links.dart';

typedef _Run = ({int code, String out, String err});

/// Страница с цитатой, разбитой тегами, сущностями, переносами строк и
/// типографскими кавычками — как это бывает на реальных сайтах.
const _quotePage = '''
<!doctype html>
<html><head><title>Test</title>
<style>p { color: red }</style>
<script>var hidden = "Script text must not match";</script>
</head><body>
<!-- Comment text must not match -->
<p>Reflected attacks are those where the injected script is
  <a href="#">reflected</a> off the web server, such as in an
  <em>error&nbsp;message</em>.</p>
<p>The browser executes the code because it came from a &ldquo;trusted&rdquo;
server. Don&#8217;t trust &lt;input&gt;.</p>
<ul><li>first</li><li>second</li></ul>
</body></html>
''';

void main() {
  late HttpServer server;
  late Directory tmp;
  late String base;
  final requests = <String>[];

  setUp(() async {
    requests.clear();
    tmp = Directory.systemTemp.createTempSync('check_links_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.host}:${server.port}';
    server.listen((req) async {
      requests.add('${req.uri.path} UA=${req.headers.value('user-agent')}');
      final res = req.response;
      switch (req.uri.path) {
        case '/page':
          res.headers.contentType = ContentType.html;
          res.write(_quotePage);
        case '/redirect':
          await res.redirect(Uri.parse('/page'));
          return;
        case '/redirect-loop':
          await res.redirect(Uri.parse('/redirect-loop'));
          return;
        case '/paywall':
          res.write('<p>Subscribe to read.</p>');
        case '/slow':
          await Future<void>.delayed(const Duration(seconds: 3));
          res.write('<p>late</p>');
        default:
          res.statusCode = HttpStatus.notFound;
      }
      await res.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  /// Колода из одного знания с заданными источниками и ссылками.
  String deckFile(
    Map<String, String> sources,
    List<(String, String, bool)> refs,
  ) {
    final deck = {
      'schema_version': 1,
      'id': 'links-test',
      'version': 1,
      'lang': 'ru',
      'topic': 'test',
      'title': 'T',
      'description': 'D',
      'sources': [
        for (final MapEntry(:key, :value) in sources.entries)
          {'id': key, 'title': key, 'url': '$base$value', 'license': 'MIT'},
      ],
      'items': [
        {
          'id': 'test.item',
          'title': 'T',
          'fact': 'F',
          'explanation_short': 'S',
          'explanation_long': 'L',
          'refs': [
            for (final (id, quote, unverifiable) in refs)
              {
                'source_id': id,
                'quote': quote,
                'quote_unverifiable': unverifiable,
              },
          ],
          'review': {'status': 'draft'},
          'questions': [
            {
              'id': 'test.item.q1',
              'type': 'flip',
              'prompt': 'P',
              'payload': {'back': 'B'},
            },
          ],
        },
      ],
    };
    final file = File('${tmp.path}/deck.json')
      ..writeAsStringSync(jsonEncode(deck));
    return file.path;
  }

  Future<_Run> run(List<String> args) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runCheckLinks(
      ['--delay-ms=0', '--timeout=1', ...args],
      out: out,
      err: err,
    );
    return (code: code, out: out.toString(), err: err.toString());
  }

  test('цитаты находятся после нормализации; код 0', () async {
    final path = deckFile(
      {'src': '/page'},
      [
        (
          'src',
          'reflected attacks are those where the injected script is reflected '
              'off the web server, such as in an error message.',
          false,
        ),
        (
          'src',
          'because it came from a "trusted" server. Don\'t trust <input>.',
          false,
        ),
        (
          'src',
          'The browser executes the code because it came from a “trusted”',
          false,
        ),
      ],
    );
    final r = await run([path]);
    expect(r.code, exitOk, reason: r.err);
    expect(r.out, contains('OK'));
    expect(r.out, contains('цитат проверено: 3'));
  });

  test('страница запрашивается один раз, с User-Agent', () async {
    final path = deckFile(
      {'src': '/page'},
      [('src', 'first', false), ('src', 'second', false)],
    );
    final r = await run([path, '--user-agent=TestBot/1']);
    expect(r.code, exitOk, reason: r.err);
    expect(requests, ['/page UA=TestBot/1']);
  });

  test('редирект на страницу с цитатой проходит', () async {
    final path = deckFile(
      {'src': '/redirect'},
      [('src', 'error message', false)],
    );
    final r = await run([path]);
    expect(r.code, exitOk, reason: r.err);
  });

  test('текст скриптов, стилей и комментариев не считается', () async {
    final path = deckFile(
      {'src': '/page'},
      [
        ('src', 'Script text must not match', false),
        ('src', 'Comment text must not match', false),
        ('src', 'color: red', false),
      ],
    );
    final r = await run([path]);
    expect(r.code, exitProblems);
    expect('[quote]'.allMatches(r.err), hasLength(3));
  });

  test('соседние блоки не слипаются, цитата через границу не ищется', () async {
    final path = deckFile({'src': '/page'}, [('src', 'firstsecond', false)]);
    final r = await run([path]);
    expect(r.code, exitProblems);
    expect(r.err, contains('/items/0/refs/0 (test.item, src)'));
  });

  test('цитата не найдена: код 1, путь до ref и начало цитаты', () async {
    final path = deckFile(
      {'src': '/page'},
      [('src', 'error message', false), ('src', 'Stored attacks are', false)],
    );
    final r = await run([path]);
    expect(r.code, exitProblems);
    expect(r.err, contains('[quote] /items/0/refs/1 (test.item, src)'));
    expect(r.err, contains('"Stored attacks are"'));
    expect(r.err, isNot(contains('refs/0')));
  });

  test('404: проблема [url], цитаты этого источника не ищутся', () async {
    final path = deckFile({'gone': '/missing'}, [('gone', 'anything', false)]);
    final r = await run([path]);
    expect(r.code, exitProblems);
    expect(r.err, contains('[url] /sources/0 gone'));
    expect(r.err, contains('HTTP 404'));
    expect(r.err, isNot(contains('[quote]')));
  });

  test('quote_unverifiable: только 200, цитата не ищется', () async {
    final ok = deckFile(
      {'pay': '/paywall'},
      [('pay', 'text behind the paywall', true)],
    );
    final r = await run([ok]);
    expect(r.code, exitOk, reason: r.err);
    expect(r.out, contains('только HTTP 200 (quote_unverifiable): 1'));

    final gone = deckFile(
      {'pay': '/missing'},
      [('pay', 'text behind the paywall', true)],
    );
    final r404 = await run([gone]);
    expect(r404.code, exitProblems);
    expect(r404.err, contains('HTTP 404'));
  });

  test('бесконечный редирект — проблема, а не зависание', () async {
    final path = deckFile({'loop': '/redirect-loop'}, [('loop', 'x', false)]);
    final r = await run([path]);
    expect(r.code, exitProblems);
    expect(r.err, contains('[url] /sources/0 loop'));
  });

  test('таймаут — проблема с понятным текстом', () async {
    final path = deckFile({'slow': '/slow'}, [('slow', 'late', false)]);
    final r = await run([path]);
    expect(r.code, exitProblems);
    expect(r.err, contains('таймаут 1 с'));
  });

  test('ref на необъявленный источник — проблема [ref]', () async {
    final path = deckFile({'src': '/page'}, [('nope', 'error message', false)]);
    final r = await run([path]);
    expect(r.code, exitProblems);
    expect(r.err, contains('[ref] /items/0/refs/0 (test.item, nope)'));
  });

  test('аргументы: без колоды и с неизвестным флагом — код 2', () async {
    expect((await run([])).code, exitUsage);
    expect((await run(['--nope', 'x.json'])).code, exitUsage);
    expect((await run(['${tmp.path}/absent.json'])).code, exitUsage);
  });

  group('нормализация', () {
    test('регистр, пробелы, кавычки, тире, ё, мягкий перенос', () {
      expect(
        normalizeText('  It’s  “Quoted”\n\t— «Ёлка» con\u00ADtent x '),
        'it\'s "quoted" - "елка" content x',
      );
    });

    test('сущности: числовые, шестнадцатеричные, именованные, неизвестные', () {
      expect(
        decodeEntities('&#39;&#x27;&amp;&lt;&gt;&quot;&rsquo;&bogus;'),
        '\'\'&<>"’&bogus;',
      );
    });

    test('htmlToText: inline-теги без пробела, блочные — с пробелом', () {
      expect(
        normalizeText(htmlToText('<p>a<b>b</b>c</p><p>d</p><br>e')),
        'abc d e',
      );
    });
  });
}
