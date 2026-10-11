/// Стадия знания в FSRS (`user_item_state.state`). [code] — как в FSRS.
///
/// Строки `user_item_state` для ни разу не показанных знаний нет; [newCard]
/// нужен самому планировщику (T11).
enum SrsState {
  newCard(0),
  learning(1),
  review(2),
  relearning(3);

  const SrsState(this.code);

  final int code;

  static SrsState fromCode(int code) =>
      values.firstWhere((s) => s.code == code);
}
