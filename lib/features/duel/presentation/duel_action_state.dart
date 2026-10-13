import '../../../core/errors/app_error.dart';
import '../domain/duel.dart';

/// Состояние одного действия с дуэлью (создание, вход): идёт ли оно, чем
/// кончилось.
class DuelActionState {
  const DuelActionState({this.busy = false, this.duel, this.error});

  /// Запрос идёт: кнопка заблокирована.
  final bool busy;

  /// Успех: созданная или найденная дуэль.
  final Duel? duel;

  /// Неудача: типизированная ошибка (текст выбирает `duelErrorText`).
  final AppError? error;
}
