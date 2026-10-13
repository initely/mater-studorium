// Реестр форматов вопросов (ТЗ M4, CLAUDE.md, правило 3). Новый формат =
// папка в `features/questions/<format>/` с `QuestionModule` + одна строка в
// [defaultQuestionModules]. Код сессии (`features/session/`) не меняется.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/domain/question_type.dart';
import 'cloze/cloze_module.dart';
import 'flip/flip_module.dart';
import 'mcq/mcq_module.dart';
import 'open/open_module.dart';
import 'order/order_module.dart';
import 'question_module.dart';

/// Форматы, которые умеет показывать приложение. T29 добавит `find_error`.
final List<QuestionModule> defaultQuestionModules = List.unmodifiable([
  const McqModule(),
  const FlipModule(),
  const OpenModule(),
  const ClozeModule(),
  const OrderModule(),
]);

/// Тип вопроса → модуль формата.
class QuestionRegistry {
  QuestionRegistry(Iterable<QuestionModule> modules)
    : _byType = {for (final module in modules) module.type: module} {
    assert(
      _byType.length == modules.length,
      'два модуля с одним типом вопроса',
    );
  }

  final Map<QuestionType, QuestionModule> _byType;

  /// `null` — формат ещё не поддерживается.
  QuestionModule? moduleFor(QuestionType type) => _byType[type];

  /// Типы, которые умеем показывать: очередь сессии не берёт остальные.
  Set<QuestionType> get supportedTypes => Set.unmodifiable(_byType.keys);
}

final questionRegistryProvider = Provider<QuestionRegistry>(
  (ref) => QuestionRegistry(defaultQuestionModules),
);

/// Поддерживаемые форматы для построителя очереди (`SessionQueueBuilder`).
final supportedQuestionTypesProvider = Provider<Set<QuestionType>>(
  (ref) => ref.watch(questionRegistryProvider).supportedTypes,
);
