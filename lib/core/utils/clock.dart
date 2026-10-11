import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Источник текущего времени. Единственное место, где разрешён `DateTime.now()`.
/// Всегда возвращает UTC. В тестах подменяется через `overrides`.
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);
