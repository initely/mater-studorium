import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mater_studorium/core/utils/clock.dart';

/// Фиксирует время в тестах: `pumpApp(w, overrides: [fixedClock(t)])`
/// или `ProviderContainer(overrides: [fixedClock(t)])`.
Override fixedClock(DateTime now) =>
    clockProvider.overrideWithValue(() => now.toUtc());
