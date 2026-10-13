import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../catalog/domain/question_payload.dart';
import '../../explanations/domain/explanation.dart';
import '../domain/duel_answer.dart';
import '../domain/duel_result.dart';
import 'format_duel_time.dart';
import 'isolate_name.dart';

/// Результат завершённой дуэли (ТЗ M10, §8.4): счёт и время, по каждому
/// вопросу «твой ответ / ответ соперника / верный» и `explanation_short`.
/// Верно и неверно подписаны словами и значком, не только цветом.
class DuelResultView extends StatelessWidget {
  const DuelResultView({super.key, required this.data});

  final DuelResultData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = data.duel.otherName;
    final opponent = name == null ? l10n.duelResultOpponent : isolateName(name);
    final result = data.result;
    final headline = switch (result.outcome) {
      DuelOutcome.won => l10n.duelResultWon,
      DuelOutcome.lost =>
        name == null
            ? l10n.duelResultLost
            : l10n.duelResultLostNamed(isolateName(name)),
      DuelOutcome.draw => l10n.duelResultDraw,
    };
    final total = data.rows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            headline,
            key: const Key('duel-result-headline'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(
              child: _ScoreCard(
                key: const Key('duel-result-mine'),
                who: l10n.duelResultYou,
                score: result.mine,
                total: total,
              ),
            ),
            Expanded(
              child: _ScoreCard(
                key: const Key('duel-result-other'),
                who: opponent,
                score: result.other,
                total: total,
              ),
            ),
          ],
        ),
        Text(
          l10n.duelResultRule,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (data.rows.every((r) => r.content == null))
          Text(
            l10n.duelResultDeckMissing,
            key: const Key('duel-result-deck-missing'),
            textAlign: TextAlign.center,
          ),
        for (var i = 0; i < data.rows.length; i++)
          _QuestionCard(
            key: Key('duel-result-q-${data.rows[i].questionId}'),
            number: i + 1,
            row: data.rows[i],
            opponent: opponent,
            hasOpponentName: name != null,
          ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    super.key,
    required this.who,
    required this.score,
    required this.total,
  });

  final String who;
  final DuelSideScore score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = formatDuelTime(score.totalMs);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.duelResultScoreSemantics(who, score.correct, total, time),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                who,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                l10n.duelResultScore(score.correct, total),
                style: theme.textTheme.headlineSmall,
              ),
              Text(l10n.duelResultTime(time)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.number,
    required this.row,
    required this.opponent,
    required this.hasOpponentName,
  });

  final int number;
  final DuelResultRow row;
  final String opponent;
  final bool hasOpponentName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final content = row.content;
    final payload = content?.question.payload;
    final mcq = payload is McqPayload ? payload : null;
    final explanation = content == null
        ? null
        : Explanation.of(content.item, content.question).short;

    String optionTexts(List<String> ids) => [
      for (final id in ids)
        for (final o in mcq!.options)
          if (o.id == id) o.text,
    ].join('; ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.duelResultQuestionTitle(number),
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (content == null)
              Text(
                l10n.duelResultQuestionUnavailable,
                key: Key('duel-result-unavailable-${row.questionId}'),
              )
            else
              Text(content.question.prompt, style: theme.textTheme.titleMedium),
            _AnswerLine(
              keyPrefix: 'mine-${row.questionId}',
              label: l10n.duelResultYourAnswer,
              record: row.mine,
              optionTexts: mcq == null ? null : optionTexts,
            ),
            _AnswerLine(
              keyPrefix: 'other-${row.questionId}',
              label: hasOpponentName
                  ? l10n.duelResultTheirAnswerNamed(opponent)
                  : l10n.duelResultTheirAnswer,
              record: row.other,
              optionTexts: mcq == null ? null : optionTexts,
            ),
            if (mcq != null)
              Text.rich(
                key: Key('duel-result-correct-${row.questionId}'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${l10n.duelResultCorrectAnswer}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: optionTexts(mcq.correct)),
                  ],
                ),
              ),
            if (explanation != null)
              Text.rich(
                key: Key('duel-result-explanation-${row.questionId}'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${l10n.duelResultExplanation}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: explanation),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.keyPrefix,
    required this.label,
    required this.record,
    required this.optionTexts,
  });

  final String keyPrefix;
  final String label;
  final DuelAnswerRecord? record;
  final String Function(List<String> ids)? optionTexts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final r = record;
    if (r == null) {
      return Text(
        '$label: ${l10n.duelResultNoAnswer}',
        key: Key('duel-result-$keyPrefix'),
      );
    }
    final picked = r.wasSkipped
        ? l10n.duelResultSkipped
        : optionTexts == null
        ? null
        : (() {
            final text = optionTexts!(r.selectedOptionIds);
            return text.isEmpty ? l10n.duelResultUnknownAnswer : text;
          })();
    final verdict = r.isCorrect ? l10n.duelResultRight : l10n.duelResultWrong;
    final time = r.wasSkipped
        ? null
        : l10n.duelResultTimeOfAnswer(formatDuelTime(r.durationMs));
    final text = [?picked, verdict, ?time].join(' · ');
    return Row(
      key: Key('duel-result-$keyPrefix'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Icon(
          r.isCorrect ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: r.isCorrect ? scheme.primary : scheme.error,
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
