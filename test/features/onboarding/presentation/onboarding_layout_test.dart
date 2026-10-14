// Раскладка онбординга (POLISH п. 2): кнопки на всех шагах стоят на одних
// местах, содержимое не теряется на маленьком экране, при повороте и шрифте
// 200%.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/reminders/data/reminder_providers.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/fake_notification_scheduler.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/unmount_app.dart';

const _next = Key('onboarding-next');
const _back = Key('onboarding-back');
const _finish = Key('onboarding-finish');

void _screen(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Четыре шага (напоминание поддерживается, как на Android).
Future<void> _pump(WidgetTester tester) async {
  await tester.pumpRouterApp(
    overrides: [
      ...appOverrides(memoryDb()),
      notificationSchedulerProvider.overrideWithValue(
        FakeNotificationScheduler(granted: false),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _forward(WidgetTester tester) async {
  await tester.tap(find.byKey(_next));
  await tester.pumpAndSettle();
}

Finder get _primary => find.byWidgetPredicate(
  (w) => w.key == _next || w.key == _finish,
  description: 'основная кнопка шага',
);

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// Основная кнопка и «Назад» на каждом из 4 шагов; у шага 1 «Назад» нет.
Future<({List<Rect> primary, List<Rect?> back})> _walk(
  WidgetTester tester,
) async {
  final primary = <Rect>[];
  final back = <Rect?>[];
  for (var step = 0; step < 4; step++) {
    primary.add(_rect(tester, _primary));
    back.add(step == 0 ? null : _rect(tester, find.byKey(_back)));
    if (step < 3) await _forward(tester);
  }
  return (primary: primary, back: back);
}

void _expectSamePlace(List<Rect> primary, List<Rect?> back) {
  for (final r in primary) {
    expect(r.left, primary.first.left);
    expect(r.right, primary.first.right);
    expect(r.bottom, primary.first.bottom, reason: 'основная кнопка прыгает');
  }
  final backs = back.whereType<Rect>().toList();
  for (final r in backs) {
    expect(r, backs.first, reason: '«Назад» прыгает');
  }
}

void main() {
  group('единое расположение кнопок', () {
    testWidgets('телефон: «Далее» и «Назад» на одних местах на всех шагах', (
      tester,
    ) async {
      _screen(tester, const Size(360, 800));
      await _pump(tester);
      final r = await _walk(tester);
      _expectSamePlace(r.primary, r.back);
      // «Назад» ниже основной кнопки, оба внизу экрана.
      expect(r.back[1]!.top, greaterThanOrEqualTo(r.primary[1].bottom));
      expect(r.back[1]!.bottom, lessThanOrEqualTo(800));
      await tester.unmountApp();
    });

    testWidgets('на шаге 1 место «Назад» зарезервировано, но пусто', (
      tester,
    ) async {
      _screen(tester, const Size(360, 800));
      await _pump(tester);
      expect(find.byKey(_back), findsNothing);
      final slot = _rect(tester, find.byKey(const Key('onboarding-back-slot')));
      await _forward(tester);
      expect(_rect(tester, find.byKey(_back)).top, slot.top);
      await tester.unmountApp();
    });

    testWidgets('широкий экран: кнопки не растягиваются шире колонки 560', (
      tester,
    ) async {
      _screen(tester, const Size(1200, 800));
      await _pump(tester);
      final r = await _walk(tester);
      _expectSamePlace(r.primary, r.back);
      for (final p in r.primary) {
        expect(p.width, lessThanOrEqualTo(560));
        expect((p.center.dx - 600).abs(), lessThan(1));
      }
      await tester.unmountApp();
    });
  });

  group('маленький экран, поворот и крупный шрифт', () {
    for (final c in [
      ('портрет 360x640, шрифт 200%', const Size(360, 640), 2.0),
      ('альбом 640x360, шрифт 200%', const Size(640, 360), 2.0),
      ('портрет 320x568, шрифт 200%', const Size(320, 568), 2.0),
      ('альбом 640x360, шрифт 100%', const Size(640, 360), 1.0),
    ]) {
      testWidgets('${c.$1}: без переполнения, кнопки на экране и одни и те же, '
          'текст доступен прокруткой', (tester) async {
        _screen(tester, c.$2, textScale: c.$3);
        await _pump(tester);
        final screen = Offset.zero & c.$2;

        final r = await _walk(tester);
        expect(tester.takeException(), isNull);
        _expectSamePlace(r.primary.sublist(0, 3), r.back.sublist(0, 3));
        for (final rect in [...r.primary, ...r.back.whereType<Rect>()]) {
          expect(screen.contains(rect.topLeft), isTrue, reason: '$rect');
          expect(screen.contains(rect.bottomRight), isTrue, reason: '$rect');
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        await tester.unmountApp();
      });
    }

    testWidgets('шаг «Колода» при 200% в альбоме: заголовок, текст и список '
        'прокручиваются, «Начать» достижима', (tester) async {
      _screen(tester, const Size(640, 360), textScale: 2);
      await _pump(tester);
      for (var i = 0; i < 3; i++) {
        await _forward(tester);
      }
      expect(find.text('Шаг 4 из 4'), findsOneWidget);
      // Заголовок и текст шага в дереве, их можно показать прокруткой.
      expect(find.byKey(const Key('onboarding-title')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('onboarding-body')),
        50,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Основная кнопка не закрыта содержимым: тап проходит.
      await tester.tap(find.byKey(_finish), warnIfMissed: true);
      await tester.pumpAndSettle();
      expect(find.text('Главная'), findsOneWidget);
      await tester.unmountApp();
    });

    testWidgets('поворот посреди онбординга сохраняет шаг и кнопки на местах', (
      tester,
    ) async {
      _screen(tester, const Size(360, 800), textScale: 2);
      await _pump(tester);
      await _forward(tester);
      expect(find.text('Шаг 2 из 4'), findsOneWidget);

      tester.view.physicalSize = const Size(800, 360);
      await tester.pumpAndSettle();

      expect(find.text('Шаг 2 из 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final screen = Offset.zero & const Size(800, 360);
      expect(
        screen.contains(_rect(tester, find.byKey(_next)).bottomRight),
        isTrue,
      );
      expect(
        screen.contains(_rect(tester, find.byKey(_back)).bottomRight),
        isTrue,
      );
      await tester.unmountApp();
    });
  });

  group('доступность', () {
    testWidgets('кнопки шагов: 48 dp и подписи при шрифте 200%', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      _screen(tester, const Size(360, 640), textScale: 2);
      await _pump(tester);
      await _forward(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final key in [_next, _back]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
      expect(
        tester.getSemantics(find.byKey(const Key('onboarding-title'))).label,
        isNotEmpty,
      );
      handle.dispose();
      await tester.unmountApp();
    });
  });
}
