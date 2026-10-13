import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../data/duel_providers.dart';
import '../domain/duel.dart';
import '../domain/duel_result.dart';
import '../domain/duel_status.dart';
import 'duel_detail_notifier.dart';

/// Результат завершённой дуэли (ТЗ M10, §8.4): оба ответа по каждому вопросу,
/// счёт и время. Ответы соперника запрашиваются **только** у завершённой
/// дуэли (AC10.1: до завершения экран их не видит, даже если сервер уже их
/// отдаёт тому, кто сам закончил). Вопросы и разбор берутся из локальной
/// колоды; нет колоды — результат без текстов.
///
/// `null` — дуэля не завершена (или её нет): результата нет.
final duelResultProvider = FutureProvider.autoDispose
    .family<DuelResultData?, String>((ref, duelId) async {
      final Duel? duel = await ref.watch(duelDetailProvider(duelId).future);
      if (duel == null || duel.status != DuelStatus.finished) return null;
      final answers = await ref
          .read(duelRepositoryProvider)
          .answers(duelId, withOther: true);
      final content = await ref
          .read(duelContentSourceProvider)
          .load(duel.deckId, duel.questionIds);
      // Результат открыт: карточка на главном больше не нужна.
      try {
        await ref.read(duelSeenStoreProvider).markResultSeen(duelId);
      } on AppError {
        // Не получилось запомнить: карточка на главном останется, результат
        // от этого не страдает.
      }
      return buildDuelResult(duel: duel, content: content, answers: answers);
    });
