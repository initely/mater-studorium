import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/app/home_placeholder.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets(
    'HomePlaceholder показывает заголовок, «Начать сессию» и кнопку настроек',
    (tester) async {
      await tester.pumpApp(const HomePlaceholder());
      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('Начать сессию'), findsOneWidget);
      expect(find.text('Колоды'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    },
  );
}
