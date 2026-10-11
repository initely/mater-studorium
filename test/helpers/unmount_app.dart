import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

extension UnmountApp on WidgetTester {
  /// Размонтирует дерево и даёт отработать нулевому таймеру drift, который
  /// создаётся при отмене подписки на запрос (иначе тест падает с «Pending timers»).
  /// Вызывать в конце виджет-тестов, где экран читает drift-stream.
  Future<void> unmountApp() async {
    await pumpWidget(const SizedBox());
    await pump(Duration.zero);
  }
}
