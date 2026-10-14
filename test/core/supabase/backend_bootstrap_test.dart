// Анонимный вход и синхронизация стартуют, как только Supabase готов: сразу
// или после повторной инициализации (POLISH п. 3).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/supabase/backend_bootstrap.dart';
import 'package:mater_studorium/core/supabase/supabase_init.dart';
import 'package:mater_studorium/core/sync/data/sync_providers.dart';
import 'package:mater_studorium/features/auth/presentation/auth_session_notifier.dart';

import '../../helpers/fake_supabase.dart';

class _CountingAuth extends FakeAuthSession {
  _CountingAuth(this.builds);

  final List<int> builds;

  @override
  AuthSessionStatus build() {
    builds.add(1);
    return super.build();
  }
}

void main() {
  late List<int> authBuilds;
  late List<int> syncBuilds;

  ProviderContainer container({
    required Future<void> Function() onInit,
    bool ready = false,
  }) {
    authBuilds = [];
    syncBuilds = [];
    final c = ProviderContainer(
      overrides: [
        ...fakeBackend(onInit: onInit),
        if (ready) supabaseStatusProvider.overrideWith(ReadyStatus.new),
        authSessionProvider.overrideWith(() => _CountingAuth(authBuilds)),
        syncBootstrapProvider.overrideWith((ref) => syncBuilds.add(1)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('Supabase уже готов: вход и синхронизация стартуют сразу, один раз', () {
    final c = container(onInit: () async {}, ready: true);
    c.read(backendBootstrapProvider);
    expect(authBuilds, hasLength(1));
    expect(syncBuilds, hasLength(1));
  });

  test('инициализация не удалась: ничего не стартует; после повтора — стартует '
      'ровно один раз', () async {
    var works = false;
    final c = container(
      onInit: () async {
        if (!works) throw const FormatException('сбой');
      },
    );
    c.read(backendBootstrapProvider);
    await c.read(supabaseStatusProvider.notifier).ensureInitialized();
    expect(authBuilds, isEmpty);
    expect(syncBuilds, isEmpty);

    works = true;
    await c.read(supabaseStatusProvider.notifier).ensureInitialized();
    expect(authBuilds, hasLength(1));
    expect(syncBuilds, hasLength(1));
  });
}
