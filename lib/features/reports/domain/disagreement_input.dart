import '../../grading/domain/open_grade.dart';

/// Что пользователь указал в «не согласен с оценкой» (ТЗ M11): вердикт ИИ,
/// с которым он спорит, и необязательный комментарий. Оценку, которую он
/// считает верной, сессия берёт из выбора в шторке, ответ и балл — из
/// результата вопроса.
class DisagreementInput {
  const DisagreementInput({required this.verdict, this.comment});

  /// `correct`, `partial` или `incorrect`.
  final GradeVerdict verdict;
  final String? comment;
}
