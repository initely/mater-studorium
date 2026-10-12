import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/grading_providers.dart';
import '../domain/llm_consent.dart';

/// Согласие на проверку ответов внешней моделью. Читается лениво (при первом
/// `open` или на экране настроек); сеттер сначала пишет в хранилище, потом
/// меняет состояние (при `LocalStorageError` состояние прежнее).
class LlmConsentNotifier extends AsyncNotifier<LlmConsent> {
  @override
  Future<LlmConsent> build() => ref.watch(llmConsentRepositoryProvider).load();

  Future<void> set(LlmConsent consent) async {
    await ref.read(llmConsentRepositoryProvider).save(consent);
    if (ref.mounted) state = AsyncData(consent);
  }
}

final llmConsentProvider =
    AsyncNotifierProvider<LlmConsentNotifier, LlmConsent>(
      LlmConsentNotifier.new,
    );
