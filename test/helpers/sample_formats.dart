import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mater_studorium/features/questions/question_module.dart';
import 'package:mater_studorium/features/questions/registry.dart';

/// Реестр из заданных модулей. Сценарии на `sample.json` рассчитаны на
/// фиксированный набор форматов (mcq, flip, open); новый формат в реестре
/// меняет очередь, поэтому такие тесты закрепляют свой набор явно, а форматы
/// проверяют их собственные widget-тесты.
List<Override> registryOverrides(List<QuestionModule> modules) {
  final registry = QuestionRegistry(modules);
  return [
    questionRegistryProvider.overrideWithValue(registry),
    supportedQuestionTypesProvider.overrideWithValue(registry.supportedTypes),
  ];
}
