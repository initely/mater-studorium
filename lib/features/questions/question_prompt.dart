import 'package:flutter/material.dart';

/// Текст вопроса: общий для форматов вид и семантика заголовка.
class QuestionPrompt extends StatelessWidget {
  const QuestionPrompt(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}
