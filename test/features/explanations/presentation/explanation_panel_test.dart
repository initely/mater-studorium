import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/item_ref.dart';
import 'package:mater_studorium/features/explanations/data/link_launcher.dart';
import 'package:mater_studorium/features/explanations/domain/explanation.dart';
import 'package:mater_studorium/features/explanations/presentation/explanation_panel.dart';

import '../../../helpers/pump_app.dart';

class _FakeLauncher {
  final calls = <Uri>[];
  var result = true;
  var throws = false;

  Future<bool> call(Uri uri) async {
    calls.add(uri);
    if (throws) throw Exception('нет приложения');
    return result;
  }
}

const _owasp = ItemRef(
  sourceId: 'owasp',
  quote: 'XSS — это внедрение скриптов',
  sourceTitle: 'OWASP XSS',
  url: 'https://owasp.org/www-community/attacks/xss/',
  license: 'CC BY-SA 4.0',
);

const _plainHttp = ItemRef(
  sourceId: 'old',
  quote: '',
  sourceTitle: 'Старый сайт',
  url: 'http://old.example.com/page',
  license: 'CC0',
);

const _js = ItemRef(
  sourceId: 'bad',
  quote: '',
  sourceTitle: 'Плохой источник',
  url: 'javascript:alert(1)',
  license: '',
);

const _full = Explanation(
  short: 'Скрипт злоумышленника выполняется в браузере жертвы.',
  long:
      '**Как работает.** Сервер вставляет значение в страницу без '
      'экранирования.\n\n- пункт один\n- пункт два',
  sources: [_owasp],
);

Finder _key(String key) => find.byKey(Key(key));

Future<_FakeLauncher> _pump(WidgetTester tester, Explanation e) async {
  final launcher = _FakeLauncher();
  await tester.pumpApp(
    Scaffold(
      body: SingleChildScrollView(child: ExplanationPanel(explanation: e)),
    ),
    overrides: [linkLauncherProvider.overrideWithValue(launcher.call)],
  );
  return launcher;
}

void main() {
  group('свёрнуто, коротко, подробнее (AC6.1)', () {
    testWidgets('по умолчанию обе кнопки есть, тексты скрыты', (tester) async {
      await _pump(tester, _full);

      expect(find.text('Коротко'), findsOneWidget);
      expect(find.text('Подробнее'), findsOneWidget);
      expect(_key('explanation-short'), findsNothing);
      expect(_key('explanation-long'), findsNothing);
      expect(find.textContaining('Скрипт злоумышленника'), findsNothing);
      expect(_key('explanation-empty'), findsNothing);
    });

    testWidgets('«Коротко» раскрывается и сворачивается', (tester) async {
      await _pump(tester, _full);

      await tester.tap(_key('explanation-short-toggle'));
      await tester.pumpAndSettle();
      expect(
        find.text('Скрипт злоумышленника выполняется в браузере жертвы.'),
        findsOneWidget,
      );
      expect(_key('explanation-long'), findsNothing);

      await tester.tap(_key('explanation-short-toggle'));
      await tester.pumpAndSettle();
      expect(_key('explanation-short'), findsNothing);
    });

    testWidgets('«Подробнее»: markdown отрисован, источники показаны', (
      tester,
    ) async {
      await _pump(tester, _full);

      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      expect(_key('explanation-long'), findsOneWidget);
      // Markdown разобран: жирный фрагмент без звёздочек, пункты списка.
      expect(
        find.textContaining('Как работает.', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.text('пункт один', findRichText: true), findsOneWidget);
      expect(find.text('пункт два', findRichText: true), findsOneWidget);
      // Короткий разбор от «Подробнее» не раскрывается.
      expect(_key('explanation-short'), findsNothing);

      // Источник: название, лицензия, цитата, адрес.
      expect(find.text('Источники'), findsOneWidget);
      expect(find.text('OWASP XSS'), findsOneWidget);
      expect(find.text('Лицензия: CC BY-SA 4.0'), findsOneWidget);
      expect(find.text('«XSS — это внедрение скриптов»'), findsOneWidget);
      expect(
        find.text('https://owasp.org/www-community/attacks/xss/'),
        findsOneWidget,
      );
    });

    testWidgets('оба уровня можно открыть вместе', (tester) async {
      await _pump(tester, _full);
      await tester.tap(_key('explanation-short-toggle'));
      await tester.pumpAndSettle();
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();
      expect(_key('explanation-short'), findsOneWidget);
      expect(_key('explanation-long'), findsOneWidget);
    });

    testWidgets('нет «Коротко» — нет и кнопки', (tester) async {
      await _pump(
        tester,
        const Explanation(long: 'Только подробно', sources: [_owasp]),
      );
      expect(_key('explanation-short-toggle'), findsNothing);
      expect(_key('explanation-long-toggle'), findsOneWidget);
    });

    testWidgets('нет «Подробнее» — нет и кнопки', (tester) async {
      await _pump(tester, const Explanation(short: 'Только коротко'));
      expect(_key('explanation-short-toggle'), findsOneWidget);
      expect(_key('explanation-long-toggle'), findsNothing);
    });

    testWidgets('только источники: «Подробнее» показывает их без текста', (
      tester,
    ) async {
      await _pump(tester, const Explanation(sources: [_owasp]));
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();
      expect(find.text('OWASP XSS'), findsOneWidget);
    });
  });

  group('знание без разбора', () {
    testWidgets('аккуратное пустое состояние вместо кнопок', (tester) async {
      await _pump(tester, const Explanation());

      expect(_key('explanation-empty'), findsOneWidget);
      expect(find.text('К этому знанию разбора нет.'), findsOneWidget);
      expect(_key('explanation-short-toggle'), findsNothing);
      expect(_key('explanation-long-toggle'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ссылки (AC6.2, ревью T10)', () {
    testWidgets('https открывается во внешнем приложении', (tester) async {
      final launcher = await _pump(tester, _full);
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      await tester.tap(_key('explanation-source-0-open'));
      await tester.pumpAndSettle();

      expect(launcher.calls, [
        Uri.parse('https://owasp.org/www-community/attacks/xss/'),
      ]);
      expect(find.text('Не удалось открыть ссылку.'), findsNothing);
    });

    testWidgets('не https не открывается, а показывается текстом', (
      tester,
    ) async {
      final launcher = await _pump(
        tester,
        const Explanation(long: 'Текст', sources: [_plainHttp, _js]),
      );
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      // Кнопок «Открыть источник» нет, адрес виден как текст, есть пояснение.
      expect(_key('explanation-source-0-open'), findsNothing);
      expect(_key('explanation-source-1-open'), findsNothing);
      expect(find.text('http://old.example.com/page'), findsOneWidget);
      expect(find.text('javascript:alert(1)'), findsOneWidget);
      expect(_key('explanation-source-0-not-https'), findsOneWidget);
      expect(_key('explanation-source-1-not-https'), findsOneWidget);
      expect(find.text('Открыть источник'), findsNothing);
      expect(launcher.calls, isEmpty);
    });

    testWidgets('https и не https рядом: открывается только https', (
      tester,
    ) async {
      final launcher = await _pump(
        tester,
        const Explanation(long: 'Текст', sources: [_plainHttp, _owasp]),
      );
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      expect(_key('explanation-source-0-open'), findsNothing);
      await tester.tap(_key('explanation-source-1-open'));
      await tester.pumpAndSettle();
      expect(launcher.calls.map((u) => u.scheme), ['https']);
    });

    testWidgets('запуск не удался: сообщение, без падения', (tester) async {
      final launcher = await _pump(tester, _full);
      launcher.result = false;
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      await tester.tap(_key('explanation-source-0-open'));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось открыть ссылку.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('исключение платформы: то же сообщение', (tester) async {
      final launcher = await _pump(tester, _full);
      launcher.throws = true;
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      await tester.tap(_key('explanation-source-0-open'));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось открыть ссылку.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ссылка в тексте: открывается, только если она из источников', (
      tester,
    ) async {
      final launcher = await _pump(
        tester,
        const Explanation(
          long:
              '[из источников](https://owasp.org/www-community/attacks/xss/) '
              'и [чужая](https://evil.example.com/) '
              'и [не https](http://owasp.org/www-community/attacks/xss/)',
          sources: [_owasp],
        ),
      );
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      Future<void> tapLink(String text) async {
        final rich = find.textContaining(text, findRichText: true);
        // Тап в начало фрагмента-ссылки внутри RichText.
        final box = tester.getTopLeft(rich.first);
        await tester.tapAt(box + const Offset(4, 8));
        await tester.pumpAndSettle();
      }

      await tapLink('из источников');
      expect(launcher.calls, [
        Uri.parse('https://owasp.org/www-community/attacks/xss/'),
      ]);

      launcher.calls.clear();
      // Остальные ссылки в тексте рядом: попадаем жестом по распознавателю.
      final spans = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          if (span.recognizer != null) spans.add(span);
          span.children?.forEach(collect);
        }
      }

      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        collect(rich.text);
      }
      expect(spans.length, 3);
      final recognizers = {for (final s in spans) s.text: s.recognizer};
      (recognizers['чужая']! as dynamic).onTap();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Эта ссылка не входит в источники колоды, '
          'поэтому не открыта.',
        ),
        findsOneWidget,
      );
      (recognizers['не https']! as dynamic).onTap();
      await tester.pumpAndSettle();
      expect(launcher.calls, isEmpty);
    });

    testWidgets('картинка в markdown не загружается, виден альт-текст', (
      tester,
    ) async {
      await _pump(
        tester,
        const Explanation(
          long: 'Схема ![схема атаки](https://x.example/a.png)',
        ),
      );
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('схема атаки'), findsOneWidget);
    });
  });

  group('доступность', () {
    testWidgets('кнопки и «Открыть источник» не меньше 48 dp', (tester) async {
      await _pump(tester, _full);
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      for (final key in [
        'explanation-short-toggle',
        'explanation-long-toggle',
        'explanation-source-0-open',
      ]) {
        final size = tester.getSize(_key(key));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
      }
    });

    testWidgets(
      'состояние раскрытия передаётся семантикой, не только иконкой',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _full);

        expect(
          tester.getSemantics(_key('explanation-short-toggle')),
          isSemantics(
            label: 'Коротко',
            isButton: true,
            hasExpandedState: true,
            isExpanded: false,
          ),
        );

        await tester.tap(_key('explanation-short-toggle'));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(_key('explanation-short-toggle')),
          isSemantics(
            label: 'Коротко',
            isButton: true,
            hasExpandedState: true,
            isExpanded: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets('кнопка источника подписана названием источника', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _full);
      await tester.tap(_key('explanation-long-toggle'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Открыть источник «OWASP XSS» в браузере'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
