import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';

void main() {
  test('ошибки типизированы и хранят причину', () {
    final cause = StateError('x');
    const AppError network = NetworkError('n');
    final AppError unexpected = UnexpectedError('u', cause: cause);

    expect(network, isA<Exception>());
    expect(unexpected.cause, same(cause));
    expect(unexpected.toString(), 'UnexpectedError(u)');
    // sealed: switch исчерпывающий без default.
    final label = switch (network) {
      NetworkError() => 'network',
      AuthError() => 'auth',
      ItemIdCollisionError() => 'collision',
      QuestionIdCollisionError() => 'question_collision',
      DeckFormatError() => 'format',
      DeckSchemaTooNewError() => 'schema',
      DeckNotFoundError() => 'not_found',
      LocalStorageError() => 'storage',
      SyncRejectedError() => 'rejected',
      QuotaExceededError() => 'quota',
      RequestRejectedError() => 'request_rejected',
      ProviderUnavailableError() => 'provider_unavailable',
      DuelCodeNotFoundError() => 'duel_not_found',
      DuelFullError() => 'duel_full',
      DuelLimitError() => 'duel_limit',
      DuelNotEnoughQuestionsError() => 'duel_not_enough',
      DuelClosedError() => 'duel_closed',
      UnexpectedError() => 'unexpected',
    };
    expect(label, 'network');
  });
}
