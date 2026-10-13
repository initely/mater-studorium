/// Статус дуэли (ТЗ §7.2). `expired` сервер при чтении выводит сам по сроку
/// (карточка T22, п. 4), поэтому клиент получает его в ответе.
enum DuelStatus {
  /// Ждём соперника.
  open,

  /// Соперник вошёл, идёт игра.
  active,

  /// Оба ответили на все вопросы.
  finished,

  /// Срок (72 часа) вышел, а дуэль не завершена.
  expired;

  static DuelStatus fromWire(String wire) =>
      values.firstWhere((s) => s.name == wire);
}
