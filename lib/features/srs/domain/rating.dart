/// Оценка ответа (ТЗ §4.1). [code] — значение в БД и на сервере, как в FSRS.
enum Rating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const Rating(this.code);

  final int code;

  static Rating fromCode(int code) => values.firstWhere((r) => r.code == code);
}
