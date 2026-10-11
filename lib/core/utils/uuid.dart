import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// uuid v4 (RFC 4122) строкой в нижнем регистре. Случайность передаётся
/// снаружи: в тестах — `Random(seed)`.
String generateUuidV4(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // версия 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // вариант RFC 4122
  String hex(int from, int to) => [
    for (var i = from; i < to; i++) bytes[i].toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Генератор клиентских идентификаторов (`review_logs.id`): криптостойкий
/// источник случайности, чтобы id с разных устройств не совпадали. В тестах
/// подменяется.
final uuidGeneratorProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () => generateUuidV4(random);
});

/// Источник случайности для перемешивания и выбора варианта. В тестах
/// подменяется на `Random(seed)`.
final randomProvider = Provider<Random>((ref) => Random());
