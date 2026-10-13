import '../../../core/l10n/app_localizations.dart';
import '../domain/duel.dart';
import '../domain/duel_status.dart';
import 'isolate_name.dart';

/// Короткая подпись состояния дуэли: «Ждём соперника», «Саша в дуэли», …
/// [status] — статус на сейчас (`Duel.statusAt`).
String duelStatusText(AppLocalizations l10n, Duel duel, DuelStatus status) =>
    switch (status) {
      DuelStatus.open => l10n.duelStatusOpen,
      DuelStatus.active =>
        duel.otherName == null
            ? l10n.duelStatusActive
            : l10n.duelStatusActiveNamed(isolateName(duel.otherName!)),
      DuelStatus.finished => l10n.duelStatusFinished,
      DuelStatus.expired => l10n.duelStatusExpired,
    };
