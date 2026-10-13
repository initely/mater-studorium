import 'package:freezed_annotation/freezed_annotation.dart';

import 'duel_status.dart';

part 'duel.freezed.dart';

/// Дуэль глазами одного из участников (ответ RPC `create_duel`, `join_duel`,
/// `get_duel`, `my_duels`, ТЗ M10).
@freezed
abstract class Duel with _$Duel {
  const factory Duel({
    required String id,

    /// Код приглашения; сервер отдаёт его только создателю.
    String? code,
    required String deckId,

    /// Версия колоды, из которой выбраны вопросы.
    required int deckVersion,

    /// Ровно 5 id вопросов, зафиксированных при создании.
    required List<String> questionIds,
    required DuelStatus status,

    /// UTC.
    required DateTime createdAt,

    /// UTC; `createdAt` + 72 часа.
    required DateTime expiresAt,
    required bool isCreator,

    /// Соперник уже вошёл (у соперника — всегда `true`: «другой» — создатель).
    required bool otherJoined,

    /// Имя другого участника; `null`, если его нет или он не задал имя.
    String? otherName,

    /// Когда я ответил на все вопросы (UTC); `null`, пока не ответил.
    DateTime? myDoneAt,

    /// Когда на все вопросы ответил другой участник (UTC).
    DateTime? otherDoneAt,
  }) = _Duel;

  const Duel._();

  /// Статус на момент [now]: незавершённая дуэль после срока — `expired`
  /// (сервер выводит то же при каждом чтении, но экран мог открыться раньше,
  /// чем срок вышел).
  DuelStatus statusAt(DateTime now) =>
      (status == DuelStatus.open || status == DuelStatus.active) &&
          !expiresAt.isAfter(now)
      ? DuelStatus.expired
      : status;

  /// Сколько осталось до конца срока; не меньше нуля.
  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}
