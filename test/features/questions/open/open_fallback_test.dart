import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/questions/open/open_fallback.dart';

void main() {
  test('ошибка репозитория → причина самооценки', () {
    final reset = DateTime.utc(2026, 10, 13);
    final network = fallbackFor(const NetworkError('x'));
    expect(network.reason, OpenFallbackReason.unavailable);
    expect(network.retryable, isTrue);

    final auth = fallbackFor(const AuthError('401'));
    expect(auth.reason, OpenFallbackReason.signedOut);
    expect(auth.retryable, isFalse);

    final quota = fallbackFor(QuotaExceededError('429', resetAt: reset));
    expect(quota.reason, OpenFallbackReason.quota);
    expect(quota.resetAt, reset);
    expect(quota.retryable, isFalse);

    for (final e in <AppError>[
      const RequestRejectedError('400', status: 400),
      const UnexpectedError('мусор'),
      const LocalStorageError('диск'),
    ]) {
      final f = fallbackFor(e);
      expect(f.reason, OpenFallbackReason.unavailable, reason: '$e');
      expect(f.retryable, isFalse, reason: '$e');
    }
  });
}
