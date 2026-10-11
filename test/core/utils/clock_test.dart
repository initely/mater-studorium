import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/utils/clock.dart';

import '../../helpers/fixed_clock.dart';

void main() {
  test('по умолчанию время в UTC', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(clockProvider)().isUtc, isTrue);
  });

  test('в тесте время фиксируется через fixedClock', () {
    final container = ProviderContainer(
      overrides: [fixedClock(DateTime.utc(2026, 1, 2, 3, 4, 5))],
    );
    addTearDown(container.dispose);
    final now = container.read(clockProvider);
    expect(now(), DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(now(), now());
  });
}
