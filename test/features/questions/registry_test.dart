import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/questions/cloze/cloze_module.dart';
import 'package:mater_studorium/features/questions/find_error/find_error_module.dart';
import 'package:mater_studorium/features/questions/flip/flip_module.dart';
import 'package:mater_studorium/features/questions/mcq/mcq_module.dart';
import 'package:mater_studorium/features/questions/open/open_module.dart';
import 'package:mater_studorium/features/questions/order/order_module.dart';
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
  test('по умолчанию зарегистрированы все шесть форматов', () {
    final registry = QuestionRegistry(defaultQuestionModules);
    expect(registry.moduleFor(QuestionType.mcq), isA<McqModule>());
    expect(registry.moduleFor(QuestionType.flip), isA<FlipModule>());
    expect(registry.moduleFor(QuestionType.open), isA<OpenModule>());
    expect(registry.moduleFor(QuestionType.cloze), isA<ClozeModule>());
    expect(registry.moduleFor(QuestionType.order), isA<OrderModule>());
    expect(registry.moduleFor(QuestionType.findError), isA<FindErrorModule>());
    expect(registry.supportedTypes, {
      QuestionType.mcq,
      QuestionType.flip,
      QuestionType.open,
      QuestionType.cloze,
      QuestionType.order,
      QuestionType.findError,
    });
  });

  test('формата нет в реестре — moduleFor возвращает null', () {
    final registry = QuestionRegistry(const [McqModule()]);
    expect(registry.moduleFor(QuestionType.mcq), isA<McqModule>());
    for (final type in QuestionType.values.where(
      (t) => t != QuestionType.mcq,
    )) {
      expect(registry.moduleFor(type), isNull, reason: '$type');
    }
  });

  test('новый формат добавляется записью в реестр, без правок сессии', () {
    final registry = QuestionRegistry([
      const McqModule(),
      const _FakeModule(QuestionType.findError),
    ]);
    expect(registry.moduleFor(QuestionType.findError), isA<_FakeModule>());
    expect(registry.supportedTypes, contains(QuestionType.findError));
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
      QuestionType.open,
      QuestionType.cloze,
      QuestionType.order,
      QuestionType.findError,
    });

    final custom = ProviderContainer(
      overrides: [
        questionRegistryProvider.overrideWithValue(
          QuestionRegistry(const [_FakeModule(QuestionType.mcq)]),
        ),
      ],
    );
    addTearDown(custom.dispose);
    expect(custom.read(supportedQuestionTypesProvider), {QuestionType.mcq});
  });
}
