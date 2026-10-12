import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_providers.dart';
import '../../../core/sync/data/sync_providers.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/uuid.dart';
import '../../session/data/session_providers.dart';
import '../domain/reports_repository.dart';
import 'drift_reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => DriftReportsRepository(
    db: ref.watch(appDatabaseProvider),
    userId: ref.watch(sessionUserIdProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(uuidGeneratorProvider),
    onQueued: ref.watch(syncRequestProvider),
  ),
);
