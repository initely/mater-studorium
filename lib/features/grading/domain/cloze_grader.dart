import '../../catalog/domain/payload_parts.dart';
import '../../catalog/domain/question_payload.dart';
import '../../srs/domain/answer_outcome.dart';

/// Вердикт по одному пропуску `cloze`.
enum ClozeBlankVerdict {
  /// Совпало с допустимым ответом после нормализации (или как число).
  correct,

  /// Принято с опечаткой: расстояние Левенштейна 1, длина ответа ≥ 6.
  typo,

  /// Не совпало, в том числе пустой ответ.
  wrong,
}

/// Разбор одного пропуска: вердикт и ответ, который показываем как верный.
class ClozeBlankGrade {
  const ClozeBlankGrade({
    required this.id,
    required this.verdict,
    required this.expected,
  });

  final String id;
  final ClozeBlankVerdict verdict;

  /// Первый из `accepted` (ТЗ M4: «первый показывается как правильный»).
  final String expected;

  bool get isAccepted => verdict != ClozeBlankVerdict.wrong;
}

/// Результат проверки `cloze` (ТЗ §4.3).
class ClozeGrade {
  const ClozeGrade({required this.outcome, required this.blanks});

  /// `autoCorrect`, `clozeTypo` (все приняты, есть опечатка) или
  /// `autoIncorrect` (хотя бы один пропуск неверен).
  final AnswerOutcome outcome;

  /// По одному разбору на пропуск, в порядке `payload.blanks`.
  final List<ClozeBlankGrade> blanks;

  bool get isCorrect => outcome != AnswerOutcome.autoIncorrect;
}

/// Минимальная длина ответа, с которой прощается одна опечатка (ТЗ §4.3).
const int kClozeTypoMinLength = 6;

final _edgePunctuation = RegExp(
  r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
  unicode: true,
);
final _spaces = RegExp(r'\s+');

/// Нормализация ответа и допустимых вариантов: lower, `ё` → `е`, схлопнутые
/// пробелы, без пунктуации по краям (ТЗ §4.2 п. 2 и §4.3).
String normalizeClozeAnswer(String raw) => raw
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(_spaces, ' ')
    .trim()
    .replaceAll(_edgePunctuation, '')
    .trim();

/// Число из нормализованной строки; запятая как десятичный разделитель.
/// `null`, если это не число.
double? _asNumber(String normalized) {
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized.replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

/// Расстояние Левенштейна (вставка, удаление, замена).
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var best = previous[j - 1] + cost;
      if (previous[j] + 1 < best) best = previous[j] + 1;
      if (current[j - 1] + 1 < best) best = current[j - 1] + 1;
      current[j] = best;
    }
    previous = current;
  }
  return previous[b.length];
}

ClozeBlankVerdict _gradeBlank(ClozeBlank blank, String? answer) {
  final given = normalizeClozeAnswer(answer ?? '');
  if (given.isEmpty) return ClozeBlankVerdict.wrong;
  final givenNumber = _asNumber(given);
  var typo = false;
  for (final candidate in blank.accepted) {
    final accepted = normalizeClozeAnswer(candidate);
    if (accepted.isEmpty) continue;
    if (accepted == given) return ClozeBlankVerdict.correct;
    final acceptedNumber = _asNumber(accepted);
    if (acceptedNumber != null || givenNumber != null) {
      // Числа сравниваются как числа и опечатку не прощают: 443 и 444
      // разные ответы.
      if (acceptedNumber != null &&
          givenNumber != null &&
          acceptedNumber == givenNumber) {
        return ClozeBlankVerdict.correct;
      }
      continue;
    }
    if (given.length >= kClozeTypoMinLength &&
        accepted.length >= kClozeTypoMinLength &&
        levenshtein(given, accepted) <= 1) {
      typo = true;
    }
  }
  return typo ? ClozeBlankVerdict.typo : ClozeBlankVerdict.wrong;
}

/// Проверяет ответы на `cloze`: [answers] — текст по id пропуска. Верно,
/// только если приняты все пропуски; опечатка хотя бы в одном даёт
/// `clozeTypo` (Hard), неверный пропуск — `autoIncorrect`.
ClozeGrade gradeCloze(ClozePayload payload, Map<String, String> answers) {
  final blanks = [
    for (final blank in payload.blanks)
      ClozeBlankGrade(
        id: blank.id,
        verdict: _gradeBlank(blank, answers[blank.id]),
        expected: blank.accepted.isEmpty ? '' : blank.accepted.first,
      ),
  ];
  final AnswerOutcome outcome;
  if (blanks.any((b) => b.verdict == ClozeBlankVerdict.wrong)) {
    outcome = AnswerOutcome.autoIncorrect;
  } else if (blanks.any((b) => b.verdict == ClozeBlankVerdict.typo)) {
    outcome = AnswerOutcome.clozeTypo;
  } else {
    outcome = AnswerOutcome.autoCorrect;
  }
  return ClozeGrade(outcome: outcome, blanks: blanks);
}
