import '../../../core/db/settings_dao.dart';
import '../../../core/errors/app_error.dart';
import '../domain/llm_consent.dart';

const _kLlmConsent = 'llm_consent';

/// [LlmConsentRepository] поверх таблицы `app_settings` (ADR-27): ключ
/// `llm_consent`, значения `granted` / `declined`; нет ключа или мусор —
/// [LlmConsent.unknown] (спросим снова).
class DriftLlmConsentRepository implements LlmConsentRepository {
  DriftLlmConsentRepository(this._dao);

  final SettingsDao _dao;

  @override
  Future<LlmConsent> load() => _guard(() async {
    final raw = (await _dao.readAll())[_kLlmConsent];
    return switch (raw) {
      'granted' => LlmConsent.granted,
      'declined' => LlmConsent.declined,
      _ => LlmConsent.unknown,
    };
  });

  @override
  Future<void> save(LlmConsent consent) => _guard(
    () => _dao.write(
      _kLlmConsent,
      consent == LlmConsent.unknown ? '' : consent.name,
    ),
  );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Exception catch (e) {
      throw LocalStorageError('ошибка локальных настроек', cause: e);
    }
  }
}
