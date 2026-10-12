import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/settings/presentation/settings_screen.dart';

import '../../../helpers/app_fixtures.dart';
import '../../../helpers/db_fixtures.dart';
import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'переключатель согласия на проверку моделью пишется в хранилище',
    (tester) async {
      final db = memoryDb();
      await tester.pumpApp(const SettingsScreen(), overrides: appOverrides(db));
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('settings-llm-consent'));
      await tester.ensureVisible(tile);
      expect(find.text('Проверка ответов'), findsOneWidget);
      // Пока не согласились, наружу ничего не уходит: переключатель выключен.
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      expect((await db.settingsDao.readAll())['llm_consent'], 'granted');

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect((await db.settingsDao.readAll())['llm_consent'], 'declined');
    },
  );
}
