import '../../../core/l10n/app_localizations.dart';
import '../domain/duel.dart';
import '../domain/duel_stage.dart';
import '../domain/duel_status.dart';
import 'isolate_name.dart';

/// Короткая подпись состояния дуэли: «Твой ход», «Ждём соперника», «Ждём
/// Сашу», «Результат готов». [status] — статус на сейчас (`Duel.statusAt`),
/// [localDone] — на все вопросы отвечено, ответы ещё в очереди отправки.
String duelStatusText(
  AppLocalizations l10n,
  Duel duel,
  DuelStatus status, {
  bool localDone = false,
}) => switch (duelStageFor(duel, status, localDone: localDone)) {
  DuelStage.yourTurn => l10n.duelStatusYourTurn,
  DuelStage.waiting =>
    duel.otherJoined && duel.otherName != null
        ? l10n.duelStatusWaitingNamed(isolateName(duel.otherName!))
        : l10n.duelStatusOpen,
  DuelStage.result => l10n.duelStatusFinished,
  DuelStage.expired => l10n.duelStatusExpired,
};
