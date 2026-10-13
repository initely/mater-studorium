import 'duel.dart';
import 'duel_status.dart';

/// Как дуэль выглядит для меня (ТЗ §8.4, карточки на главном).
enum DuelStage {
  /// Я ещё не ответил на все вопросы.
  yourTurn,

  /// Я ответил на все, жду соперника (он не вошёл или не закончил).
  waiting,

  /// Оба закончили: можно смотреть результат.
  result,

  /// Срок вышел.
  expired,
}

/// Стадия дуэли [duel] при статусе [status] (`Duel.statusAt`). [localDone] —
/// на все вопросы отвечено, но часть ответов ещё не дошла до сервера
/// (лежит в очереди отправки): для меня это уже «ждём».
DuelStage duelStageFor(
  Duel duel,
  DuelStatus status, {
  bool localDone = false,
}) => switch (status) {
  DuelStatus.expired => DuelStage.expired,
  DuelStatus.finished => DuelStage.result,
  DuelStatus.open || DuelStatus.active =>
    duel.myDoneAt != null || localDone ? DuelStage.waiting : DuelStage.yourTurn,
};
