import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/utils/uuid.dart';

void main() {
  final v4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generateUuidV4: формат RFC 4122 v4', () {
    final random = Random(3);
    for (var i = 0; i < 200; i++) {
      expect(generateUuidV4(random), matches(v4));
    }
  });

  test(
    'generateUuidV4: детерминирован при одном seed, разные значения подряд',
    () {
      expect(generateUuidV4(Random(5)), generateUuidV4(Random(5)));
      final random = Random(5);
      expect(generateUuidV4(random), isNot(generateUuidV4(random)));
    },
  );

  test('провайдеры: криптостойкий генератор uuid и общий Random', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final next = container.read(uuidGeneratorProvider);
    final a = next();
    expect(a, matches(v4));
    expect(next(), isNot(a));
    expect(container.read(randomProvider), isA<Random>());
  });
}
