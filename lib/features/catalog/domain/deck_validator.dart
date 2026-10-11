import 'deck.dart';
import 'deck_item.dart';
import 'payload_parts.dart';
import 'question.dart';
import 'question_payload.dart';
import 'review.dart';

/// Нарушение правила колоды.
///
/// [path] — JSON Pointer до проблемного места, например
/// `/items/0/questions/1/payload/correct/0`.
final class DeckIssue {
  const DeckIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Семантические правила колоды, которые JSON Schema не выражает:
/// уникальность id, ссылки на источники, согласованность payload
/// (ТЗ M12, AC12.1). Структуру проверяет `content/schema/deck.schema.json`;
/// правила из карточки T06 проверяются и здесь, чтобы клиент мог
/// проверить колоду без JSON Schema.
///
/// [release] дополнительно требует `review.status = approved` у всех знаний.
/// Пустой список — колода корректна.
List<DeckIssue> validateDeck(Deck deck, {bool release = false}) {
  final issues = <DeckIssue>[];
  void report(String path, String message) =>
      issues.add(DeckIssue(path, message));

  // Старые версии читаются (новые поля — с умолчаниями), новые — нет
  // (ADR-19).
  if (deck.schemaVersion < 1 || deck.schemaVersion > kDeckSchemaVersion) {
    report(
      '/schema_version',
      'поддерживаются версии 1–$kDeckSchemaVersion, в колоде '
          '${deck.schemaVersion}',
    );
  }

  final sourceIds = <String>{};
  for (final (i, source) in deck.sources.indexed) {
    if (!sourceIds.add(source.id)) {
      report('/sources/$i/id', 'id "${source.id}" повторяется');
    }
    // Ссылки открываются пользователю: только абсолютный https (не file:,
    // javascript:, http:). Формат колоды не меняется, ужесточена только проверка.
    final uri = Uri.tryParse(source.url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      report(
        '/sources/$i/url',
        'нужен абсолютный https-URL, сейчас "${source.url}"',
      );
    }
    if (source.license.trim().isEmpty) {
      report('/sources/$i/license', 'не указана лицензия источника');
    }
  }

  // У знаний и вопросов общее пространство id: оба попадают в логи,
  // кэш оценок и жалобы.
  final ids = <String>{};
  for (final (i, item) in deck.items.indexed) {
    final path = '/items/$i';
    if (!ids.add(item.id)) report('$path/id', 'id "${item.id}" повторяется');
    _checkItem(item, path, sourceIds, ids, report);
    if (release && item.review.status != ReviewStatus.approved) {
      report(
        '$path/review/status',
        'для релиза нужен "approved", сейчас '
            '"${item.review.toJson()['status']}" (знание "${item.id}")',
      );
    }
  }
  return issues;
}

typedef _Report = void Function(String path, String message);

const _maxQuestionsPerItem = 4;

void _checkItem(
  DeckItem item,
  String path,
  Set<String> sourceIds,
  Set<String> ids,
  _Report report,
) {
  if (item.refs.isEmpty) {
    report('$path/refs', 'нужна хотя бы одна ссылка на источник');
  }
  for (final (r, ref) in item.refs.indexed) {
    if (!sourceIds.contains(ref.sourceId)) {
      report(
        '$path/refs/$r/source_id',
        'источник "${ref.sourceId}" не объявлен в /sources',
      );
    }
  }

  final count = item.questions.length;
  if (count < 1 || count > _maxQuestionsPerItem) {
    report(
      '$path/questions',
      'у знания должно быть 1–$_maxQuestionsPerItem вопроса, сейчас $count',
    );
  }
  for (final (q, question) in item.questions.indexed) {
    final qPath = '$path/questions/$q';
    if (!ids.add(question.id)) {
      report('$qPath/id', 'id "${question.id}" повторяется');
    }
    if (!question.id.startsWith('${item.id}.')) {
      report(
        '$qPath/id',
        'id вопроса "${question.id}" должен начинаться с "${item.id}."',
      );
    }
    _checkPayload(question, qPath, report);
  }
}

void _checkPayload(Question question, String path, _Report report) {
  final p = '$path/payload';
  switch (question.payload) {
    case McqPayload(:final options, :final correct, :final multiple):
      if (options.length < 2) {
        report(
          '$p/options',
          'нужно минимум 2 варианта, сейчас '
              '${options.length}',
        );
      }
      final optionIds = _checkUniqueIds(
        options.map((o) => o.id),
        '$p/options',
        report,
      );
      if (correct.isEmpty) report('$p/correct', 'не указан верный вариант');
      final seen = <String>{};
      for (final (k, id) in correct.indexed) {
        if (!optionIds.contains(id)) {
          report(
            '$p/correct/$k',
            'вариант "$id" не найден среди опций '
                '[${optionIds.join(', ')}]',
          );
        }
        if (!seen.add(id)) report('$p/correct/$k', 'вариант "$id" повторяется');
      }
      if (!multiple && correct.length != 1) {
        report(
          '$p/correct',
          'при multiple = false верный вариант ровно один, сейчас '
              '${correct.length}',
        );
      }

    case FlipPayload():
      break;

    case OpenPayload(:final rubric):
      if (rubric.length < 2 || rubric.length > 5) {
        report(
          '$p/rubric',
          'в рубрике должно быть 2–5 пунктов, сейчас '
              '${rubric.length}',
        );
      }
      _checkUniqueIds(rubric.map((r) => r.id), '$p/rubric', report);
      if (!rubric.any((r) => r.required)) {
        report('$p/rubric', 'нужен хотя бы один пункт с required = true');
      }
      for (final (k, point) in rubric.indexed) {
        if (point.weight < 1 || point.weight > 3) {
          report(
            '$p/rubric/$k/weight',
            'вес должен быть 1–3, сейчас '
                '${point.weight}',
          );
        }
      }

    case ClozePayload(:final blanks):
      _checkCloze(question.prompt, blanks, path, report);

    case OrderPayload(:final steps):
      if (steps.length < 3) {
        report('$p/steps', 'нужно минимум 3 шага, сейчас ${steps.length}');
      }
      _checkUniqueIds(steps.map((s) => s.id), '$p/steps', report);

    case FindErrorPayload(
      :final lines,
      :final errorLines,
      :final lineExplanations,
    ):
      final range = '1–${lines.length}';
      if (errorLines.isEmpty || errorLines.length > 2) {
        report(
          '$p/error_lines',
          'ошибочных строк должно быть 1–2, сейчас '
              '${errorLines.length}',
        );
      }
      final seen = <int>{};
      for (final (k, line) in errorLines.indexed) {
        if (line < 1 || line > lines.length) {
          report('$p/error_lines/$k', 'строка $line вне диапазона $range');
        }
        if (!seen.add(line)) {
          report('$p/error_lines/$k', 'строка $line повторяется');
        }
        if (!lineExplanations.containsKey(line)) {
          report('$p/line_explanations', 'нет пояснения для строки $line');
        }
      }
      for (final line in lineExplanations.keys) {
        if (line < 1 || line > lines.length) {
          report(
            '$p/line_explanations/$line',
            'строка $line вне диапазона $range',
          );
        }
      }
  }
}

/// Любые `{{...}}`, в том числе с недопустимым id внутри.
final _anyPlaceholder = RegExp(r'\{\{([^{}]*)\}\}');

void _checkCloze(
  String prompt,
  List<ClozeBlank> blanks,
  String path,
  _Report report,
) {
  final p = '$path/payload/blanks';
  if (blanks.isEmpty) report(p, 'нужен хотя бы один пропуск');
  final blankIds = _checkUniqueIds(blanks.map((b) => b.id), p, report);
  for (final (k, blank) in blanks.indexed) {
    if (blank.accepted.where((a) => a.trim().isNotEmpty).isEmpty) {
      report('$p/$k/accepted', 'нет ни одного допустимого ответа');
    }
  }

  final placeholderIds = <String>[];
  for (final match in _anyPlaceholder.allMatches(prompt)) {
    final whole = match[0]!;
    if (clozePlaceholder.matchAsPrefix(whole) == null) {
      report('$path/prompt', 'некорректный плейсхолдер "$whole"');
    } else {
      placeholderIds.add(match[1]!);
    }
  }
  final rest = prompt.replaceAll(_anyPlaceholder, '');
  if (rest.contains('{{') || rest.contains('}}')) {
    report('$path/prompt', 'незакрытые или лишние фигурные скобки {{ }}');
  }

  final seen = <String>{};
  for (final id in placeholderIds) {
    if (!seen.add(id)) {
      report('$path/prompt', 'плейсхолдер {{$id}} встречается дважды');
    } else if (!blankIds.contains(id)) {
      report('$path/prompt', 'для плейсхолдера {{$id}} нет пропуска в blanks');
    }
  }
  for (final (k, blank) in blanks.indexed) {
    if (!seen.contains(blank.id)) {
      report(
        '$p/$k/id',
        'пропуска "${blank.id}" нет в тексте как {{${blank.id}}}',
      );
    }
  }
}

/// Сообщает о повторах и возвращает множество id.
Set<String> _checkUniqueIds(
  Iterable<String> ids,
  String listPath,
  _Report report,
) {
  final seen = <String>{};
  for (final (k, id) in ids.indexed) {
    if (!seen.add(id)) report('$listPath/$k/id', 'id "$id" повторяется');
  }
  return seen;
}
