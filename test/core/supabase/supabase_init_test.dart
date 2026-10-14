// Инициализация Supabase и её сбои (POLISH п. 3): предикат входящих ссылок не
// бросает, повтор инициализации, провайдеры без красного экрана.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database_providers.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/supabase/supabase_config.dart';
import 'package:mater_studorium/core/supabase/supabase_init.dart';
import 'package:mater_studorium/core/sync/data/sync_providers.dart';
import 'package:mater_studorium/features/auth/data/auth_providers.dart';
import 'package:mater_studorium/features/catalog/data/catalog_providers.dart';
import 'package:mater_studorium/features/duel/data/duel_providers.dart';
import 'package:mater_studorium/features/grading/data/grading_providers.dart';
import 'package:mater_studorium/features/grading/domain/grading_repository.dart';
import 'package:mater_studorium/features/session/data/session_providers.dart';

import '../../helpers/db_fixtures.dart';
import '../../helpers/fake_supabase.dart';

/// Ссылка, на любое обращение к которой падает не `FormatException`: проверяет,
/// что предикат не пропускает вообще никаких исключений.
class _HostileUri implements Uri {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('необработанное: ${invocation.memberName}');
}

ProviderContainer _container({
  bool configured = true,
  Future<void> Function()? onInit,
}) {
  final container = ProviderContainer(
    overrides: [
      ...fakeBackend(onInit: onInit ?? () async {}, configured: configured),
      appDatabaseProvider.overrideWithValue(memoryDb()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('предикат входящих ссылок', () {
    final expected = Uri.parse(SupabaseConfig.androidRedirectUrl);

    test('возврат из Google с кодом принимается', () {
      final uri = Uri.parse('${SupabaseConfig.androidRedirectUrl}?code=abc');
      expect(isOAuthReturnUriSafe(uri, expected: expected), isTrue);
    });

    test('чужая ссылка и ссылка с токенами отклоняются', () {
      for (final raw in [
        'https://example.com/?code=abc',
        '${SupabaseConfig.androidRedirectUrl}#access_token=x&code=1',
        '${SupabaseConfig.androidRedirectUrl}#%zz=1',
        'intent:#Intent;action=android.intent.action.MAIN;end',
        ':',
      ]) {
        final uri = Uri.tryParse(raw);
        if (uri == null) continue;
        expect(
          isOAuthReturnUriSafe(uri, expected: expected),
          isFalse,
          reason: raw,
        );
      }
    });

    test('любое неожиданное исключение — отказ, а не падение', () {
      expect(isOAuthReturnUriSafe(_HostileUri(), expected: expected), isFalse);
    });

    test('адрес возврата, который не разбирается, не ломает предикат', () {
      // Без `expected` берётся Uri.tryParse(oauthRedirectUrl): даже если бы
      // он дал null, ответ — отказ.
      final uri = Uri.parse('${SupabaseConfig.androidRedirectUrl}?code=abc');
      expect(isOAuthReturnUriSafe(uri), isTrue);
    });
  });

  group('initSupabase', () {
    test('нерабочий SUPABASE_URL — понятная FormatException до обращения к '
        'supabase_flutter', () async {
      // В тестах SUPABASE_URL не задан: пустая строка.
      await expectLater(
        initSupabase(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_URL'),
          ),
        ),
      );
    });
  });

  group('SupabaseStatusNotifier', () {
    test(
      'сбой инициализации не бросает: бэкенд недоступен, причина запомнена',
      () async {
        final container = _container(
          onInit: () async => throw const FormatException(
            'Scheme not starting with alphabetic character',
            ':',
            0,
          ),
        );
        final status = container.read(supabaseStatusProvider.notifier);

        expect(await status.ensureInitialized(), isFalse);
        expect(
          container.read(supabaseStatusProvider),
          SupabaseStatus.unavailable,
        );
        expect(status.lastError, isA<FormatException>());
      },
    );

    test(
      'каждая новая попытка пробует инициализацию заново; успех — ready',
      () async {
        var attempts = 0;
        var works = false;
        final container = _container(
          onInit: () async {
            attempts++;
            if (!works) throw const FormatException('сбой');
          },
        );
        final status = container.read(supabaseStatusProvider.notifier);

        expect(await status.ensureInitialized(), isFalse);
        expect(await status.ensureInitialized(), isFalse);
        expect(attempts, 2);

        works = true;
        expect(await status.ensureInitialized(), isTrue);
        expect(attempts, 3);
        expect(container.read(supabaseStatusProvider), SupabaseStatus.ready);
        expect(status.lastError, isNull);

        // Готов: повторный вызов инициализацию не трогает.
        expect(await status.ensureInitialized(), isTrue);
        expect(attempts, 3);
      },
    );

    test('одновременные вызовы делят одну попытку', () async {
      var attempts = 0;
      final gate = Completer<void>();
      final container = _container(
        onInit: () async {
          attempts++;
          await gate.future;
        },
      );
      final status = container.read(supabaseStatusProvider.notifier);

      final a = status.ensureInitialized();
      final b = status.ensureInitialized();
      gate.complete();
      expect(await Future.wait([a, b]), [true, true]);
      expect(attempts, 1);
    });

    test('бэкенд не настроен: инициализацию не пробуем', () async {
      var attempts = 0;
      final container = _container(
        configured: false,
        onInit: () async => attempts++,
      );
      expect(
        await container
            .read(supabaseStatusProvider.notifier)
            .ensureInitialized(),
        isFalse,
      );
      expect(attempts, 0);
    });
  });

  group('провайдеры без инициализированного Supabase', () {
    // Раньше любой из них давал ProviderException «You must initialize the
    // supabase instance» и красный экран.
    test('клиент — null, зависящие провайдеры собираются', () {
      final container = _container();
      expect(container.read(supabaseClientProvider), isNull);
      expect(() => container.read(deckRemoteSourceProvider), returnsNormally);
      expect(() => container.read(authRepositoryProvider), returnsNormally);
      expect(() => container.read(syncRemoteProvider), returnsNormally);
      expect(() => container.read(duelRepositoryProvider), returnsNormally);
      expect(() => container.read(gradingRepositoryProvider), returnsNormally);
      expect(() => container.read(sessionUserIdProvider), returnsNormally);
    });

    test('вызовы к серверу — типизированный NetworkError', () async {
      final container = _container();
      await expectLater(
        container.read(deckRemoteSourceProvider).fetchDecks(),
        throwsA(isA<NetworkError>()),
      );
      await expectLater(
        container.read(authRepositoryProvider).ensureSignedIn(),
        throwsA(isA<NetworkError>()),
      );
      await expectLater(
        container.read(syncRemoteProvider).pullHiddenQuestions('u'),
        throwsA(isA<NetworkError>()),
      );
      await expectLater(
        container.read(duelRepositoryProvider).mine(),
        throwsA(isA<NetworkError>()),
      );
      await expectLater(
        container
            .read(gradingRepositoryProvider)
            .grade(
              const GradeRequest(
                deckId: 'd',
                deckVersion: 1,
                questionId: 'q',
                answerText: 'a',
                inputMode: AnswerInputMode.text,
              ),
            ),
        throwsA(isA<NetworkError>()),
      );
    });

    test('id пользователя без клиента — AuthError (нет сессии)', () {
      final container = _container();
      expect(container.read(sessionUserIdProvider), throwsA(isA<AuthError>()));
    });
  });
}
