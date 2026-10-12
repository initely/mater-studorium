import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../data/reports_providers.dart';
import '../domain/report_reason.dart';

enum ReportFormStatus { editing, saving, failed }

/// Состояние шторки «Пожаловаться»: выбранная причина и ход записи.
class ReportFormState {
  const ReportFormState({this.reason, this.status = ReportFormStatus.editing});

  final ReportReason? reason;
  final ReportFormStatus status;

  /// Можно отправлять: причина выбрана и запись не идёт.
  bool get canSend => reason != null && status != ReportFormStatus.saving;

  ReportFormState copyWith({ReportReason? reason, ReportFormStatus? status}) =>
      ReportFormState(
        reason: reason ?? this.reason,
        status: status ?? this.status,
      );
}

/// Ведёт шторку жалобы (ТЗ M11). Запись локальная (outbox + скрытие
/// вопроса), поэтому работает офлайн (AC11.1); на сервер жалоба уходит через
/// `SyncService`.
class ReportFormNotifier extends Notifier<ReportFormState> {
  @override
  ReportFormState build() => const ReportFormState();

  void select(ReportReason reason) {
    if (state.status == ReportFormStatus.saving) return;
    state = state.copyWith(reason: reason, status: ReportFormStatus.editing);
  }

  /// Записывает жалобу. `true` — записана; `false` — не записана (причина не
  /// выбрана, запись уже идёт или ошибка локальной БД: тогда `failed`).
  Future<bool> send({
    required String deckId,
    required int deckVersion,
    required String questionId,
    required String questionText,
    String? comment,
  }) async {
    final reason = state.reason;
    // Двойной тап: статус `saving` ставится до первого await.
    if (reason == null || state.status == ReportFormStatus.saving) return false;
    state = state.copyWith(status: ReportFormStatus.saving);
    try {
      await ref
          .read(reportsRepositoryProvider)
          .reportQuestion(
            deckId: deckId,
            deckVersion: deckVersion,
            questionId: questionId,
            questionText: questionText,
            reason: reason,
            comment: comment,
          );
      return true;
    } on AppError {
      if (ref.mounted) state = state.copyWith(status: ReportFormStatus.failed);
      return false;
    }
  }
}

final reportFormProvider =
    NotifierProvider.autoDispose<ReportFormNotifier, ReportFormState>(
      ReportFormNotifier.new,
    );
