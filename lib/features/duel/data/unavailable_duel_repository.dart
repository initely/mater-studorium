import '../../../core/errors/app_error.dart';
import '../domain/duel.dart';
import '../domain/duel_answer.dart';
import '../domain/duel_repository.dart';

/// Дуэли, когда Supabase не инициализирован: каждый вызов — `NetworkError`.
final class UnavailableDuelRepository implements DuelRepository {
  const UnavailableDuelRepository();

  static const _error = NetworkError('Supabase недоступен');

  @override
  Future<Duel> create({
    required String duelId,
    required String deckId,
    required int deckVersion,
    required List<String> questionIds,
  }) => Future.error(_error);

  @override
  Future<Duel> join(String code) => Future.error(_error);

  @override
  Future<Duel?> get(String duelId) => Future.error(_error);

  @override
  Future<DuelAnswers> answers(String duelId, {bool withOther = false}) =>
      Future.error(_error);

  @override
  Future<List<Duel>> mine() => Future.error(_error);

  @override
  Future<String?> displayName() => Future.error(_error);

  @override
  Future<void> setDisplayName(String? name) => Future.error(_error);
}
