import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/questions/flip/flip_module.dart';
import 'package:mater_studorium/features/questions/mcq/mcq_module.dart';
import 'package:mater_studorium/features/questions/question_module.dart';
import 'package:mater_studorium/features/questions/question_request.dart';
import 'package:mater_studorium/features/questions/registry.dart';

class _FakeModule implements QuestionModule {
  const _FakeModule(this.type);

  @override
  final QuestionType type;

  @override
  Widget build(BuildContext context, QuestionRequest request) =>
      const SizedBox();
}

void main() {
  test('по умолчанию зарегистрированы mcq и flip', () {
    final registry = QuestionRegistry(defaultQuestionModules);
    expect(registry.moduleFor(QuestionType.mcq), isA<McqModule>());
    expect(registry.moduleFor(QuestionType.flip), isA<FlipModule>());
    expect(registry.supportedTypes, {QuestionType.mcq, QuestionType.flip});
  });

  test('формата нет — moduleFor возвращает null', () {
    final registry = QuestionRegistry(defaultQuestionModules);
    for (final type in [
      QuestionType.open,
      QuestionType.cloze,
      QuestionType.order,
      QuestionType.findError,
    ]) {
      expect(registry.moduleFor(type), isNull, reason: '$type');
    }
  });

  test('новый формат добавляется записью в реестр, без правок сессии', () {
    final registry = QuestionRegistry([
      ...defaultQuestionModules,
      const _FakeModule(QuestionType.cloze),
    ]);
    expect(registry.moduleFor(QuestionType.cloze), isA<_FakeModule>());
    expect(registry.supportedTypes, contains(QuestionType.cloze));
  });

  test('два модуля с одним типом — ошибка (assert)', () {
    expect(
      () => QuestionRegistry(const [
        _FakeModule(QuestionType.mcq),
        _FakeModule(QuestionType.mcq),
      ]),
      throwsA(isA<AssertionError>()),
    );
  });

  test('провайдеры отдают реестр и поддерживаемые типы; подменяются', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(supportedQuestionTypesProvider), {
      QuestionType.mcq,
      QuestionType.flip,
    });

    final custom = ProviderContainer(
      overrides: [
        questionRegistryProvider.overrideWithValue(
          QuestionRegistry(const [_FakeModule(QuestionType.order)]),
        ),
      ],
    );
    addTearDown(custom.dispose);
    expect(custom.read(supportedQuestionTypesProvider), {QuestionType.order});
  });
}
