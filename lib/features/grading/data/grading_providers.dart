import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_init.dart';
import '../domain/grading_repository.dart';
import '../domain/llm_consent.dart';
import '../domain/open_grade.dart';
import 'drift_llm_consent_repository.dart';
import 'supabase_grading_repository.dart';

/// Оценка `open` на сервере. Без `SUPABASE_URL` и ключа (запуск без бэкенда)
/// ведёт себя как «нет сети»: самооценка. В тестах подменяется.
final gradingRepositoryProvider = Provider<GradingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? const _UnconfiguredGradingRepository()
      : SupabaseGradingRepository(client);
});

class _UnconfiguredGradingRepository implements GradingRepository {
  const _UnconfiguredGradingRepository();

  @override
  Future<OpenGrade> grade(GradeRequest request) async =>
      throw const NetworkError('Supabase не настроен');
}

final llmConsentRepositoryProvider = Provider<LlmConsentRepository>(
  (ref) => DriftLlmConsentRepository(ref.watch(settingsDaoProvider)),
);
