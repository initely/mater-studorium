import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../data/auth_providers.dart';

enum AuthSessionStatus {
  /// Входа ещё нет (идёт попытка или ждём повтора из-за сети).
  signingIn,
  signedIn,

  /// Сервер отказал во входе. Повторов нет; UI пока ничего не показывает.
  failed,
}

/// Паузы между повторами при отсутствии сети; после последней паузы повторяем
/// с тем же интервалом. Пользователю ошибку сети не показываем (AC1.1).
const authRetryDelays = [
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

/// Выполняет `ensureSignedIn()` при старте и повторяет, пока нет сети.
class AuthSessionNotifier extends Notifier<AuthSessionStatus> {
  Timer? _timer;
  var _attempt = 0;

  @override
  AuthSessionStatus build() {
    ref.onDispose(() => _timer?.cancel());
    unawaited(_signIn());
    return AuthSessionStatus.signingIn;
  }

  Future<void> _signIn() async {
    try {
      await ref.read(authRepositoryProvider).ensureSignedIn();
      if (ref.mounted) state = AuthSessionStatus.signedIn;
    } on NetworkError {
      if (!ref.mounted) return;
      final index = _attempt < authRetryDelays.length
          ? _attempt
          : authRetryDelays.length - 1;
      _attempt++;
      _timer = Timer(authRetryDelays[index], () => unawaited(_signIn()));
    } on AppError {
      if (ref.mounted) state = AuthSessionStatus.failed;
    }
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSessionStatus>(
      AuthSessionNotifier.new,
    );
