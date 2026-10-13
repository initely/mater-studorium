import 'duel.dart';
import 'duel_answer.dart';

/// Дуэли на сервере (ТЗ M10). Реализация в `data/` ходит в Supabase RPC; о
/// сервере `domain/` ничего не знает. Дуэль не влияет на FSRS (ADR-16).
///
/// Методы бросают только типизированные ошибки из `core/errors/`:
/// `AuthError` (нет входа), `NetworkError` (сеть, можно повторить),
/// `DuelCodeNotFoundError`, `DuelFullError`, `DuelLimitError`,
/// `DeckNotFoundError`, `RequestRejectedError`, `UnexpectedError`.
abstract interface class DuelRepository {
  /// Создаёт дуэль. [duelId] — uuid клиента: повтор с тем же id (после обрыва
  /// сети) возвращает ту же дуэль и тот же код.
  Future<Duel> create({
    required String duelId,
    required String deckId,
    required int deckVersion,
    required List<String> questionIds,
  });

  /// Входит по коду [code] (уже нормализованному, `normalizeDuelCode`).
  /// Повторный вход соперника и вход создателя в свою дуэль возвращают дуэль
  /// без ошибки.
  Future<Duel> join(String code);

  /// Дуэль участника; `null`, если её нет или пользователь не участник (сервер
  /// отвечает одинаково).
  Future<Duel?> get(String duelId);

  /// Ответы на вопросы дуэли [duelId]: свои всегда; ответы соперника только
  /// при [withOther] (экран результата, когда дуэль завершена) — иначе клиент
  /// их не запрашивает вовсе. Сервер отдаёт чужие ответы лишь тому, кто сам
  /// ответил на все вопросы (RLS, AC10.1).
  Future<DuelAnswers> answers(String duelId, {bool withOther = false});

  /// Дуэли пользователя, новые первыми.
  Future<List<Duel>> mine();

  /// Своё имя для соперника; `null`, если не задано.
  Future<String?> displayName();

  /// Сохраняет имя (`null` — убрать). Принимает только очищенное
  /// `sanitizeDisplayName`.
  Future<void> setDisplayName(String? name);
}
