import 'duel_question_picker.dart';

/// Скачанная колода и вопросы, которые из неё можно взять в дуэль.
class DuelDeckSnapshot {
  const DuelDeckSnapshot({required this.deckVersion, required this.candidates});

  /// Локальная версия колоды (сервер принимает версию не выше своей).
  final int deckVersion;
  final List<DuelCandidate> candidates;
}

/// Откуда клиент берёт вопросы для новой дуэли: из скачанной колоды (контента
/// колод в БД сервера нет, ADR-7). Реализация в `data/`.
abstract interface class DuelQuestionSource {
  /// Вопросы колоды допустимых форматов ([kDuelQuestionTypes]) без скрытых
  /// и без знаний, исчезнувших из версии; `null`, если колоды нет на
  /// устройстве.
  Future<DuelDeckSnapshot?> snapshot(String deckId);
}
