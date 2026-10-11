import 'dart:math';

import '../../catalog/domain/payload_parts.dart';

/// Варианты `mcq` в перемешанном порядке. Порядок определяется только
/// [seed] (сессия считает его от `question_id` и даты, ТЗ M4): при том же
/// зерне порядок тот же, поэтому перестройка и поворот экрана его не
/// меняют, а в тестах он воспроизводим. Исходный список не меняется.
List<McqOption> shuffledOptions(List<McqOption> options, int seed) =>
    [...options]..shuffle(Random(seed));
