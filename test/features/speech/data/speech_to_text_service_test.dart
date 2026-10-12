// Чистые части обёртки над `speech_to_text`: язык колоды → локаль и коды
// ошибок платформ → причина для пользователя. Сам плагин на устройстве
// (ручная проверка, T16).
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/speech/data/speech_to_text_service.dart';
import 'package:mater_studorium/features/speech/domain/speech_service.dart';

void main() {
  group('speechLocaleId', () {
    test('русский колоды → ru_RU, на web ru-RU', () {
      expect(speechLocaleId('ru'), 'ru_RU');
      expect(speechLocaleId('RU'), 'ru_RU');
      expect(speechLocaleId('ru', web: true), 'ru-RU');
      expect(speechLocaleId('en'), 'en_US');
      expect(speechLocaleId('en', web: true), 'en-US');
      expect(speechLocaleId('de'), 'de');
    });
  });

  group('pickSpeechLocale', () {
    test('точная локаль предпочтительна', () {
      expect(pickSpeechLocale('ru', ['en_US', 'ru_UA', 'ru_RU']), 'ru_RU');
    });

    test('формат с дефисом сопоставляется и возвращается как у устройства', () {
      expect(pickSpeechLocale('ru', ['en-US', 'ru-RU']), 'ru-RU');
    });

    test('нет ru_RU — любая русская', () {
      expect(pickSpeechLocale('ru', ['en_US', 'ru_UA']), 'ru_UA');
    });

    test('языка нет — null (причина «нет распознавания языка колоды»)', () {
      expect(pickSpeechLocale('ru', ['en_US', 'de_DE']), isNull);
      expect(pickSpeechLocale('ru', []), isNull);
    });
  });

  group('mapSpeechError', () {
    test('нет разрешения', () {
      for (final e in [
        'error_permission',
        'not-allowed',
        'service-not-allowed',
      ]) {
        expect(mapSpeechError(e), SpeechFailure.permissionDenied, reason: e);
      }
    });

    test('тишина и «не расслышали»', () {
      for (final e in ['error_speech_timeout', 'error_no_match', 'no-speech']) {
        expect(mapSpeechError(e), SpeechFailure.noSpeech, reason: e);
      }
    });

    test('сеть и язык', () {
      expect(mapSpeechError('error_network'), SpeechFailure.network);
      expect(mapSpeechError('error_network_timeout'), SpeechFailure.network);
      expect(mapSpeechError('network'), SpeechFailure.network);
      expect(
        mapSpeechError('error_language_not_supported'),
        SpeechFailure.languageUnavailable,
      );
      expect(
        mapSpeechError('language-not-supported'),
        SpeechFailure.languageUnavailable,
      );
    });

    test('нет поддержки, отмена пользователем и прочее', () {
      expect(mapSpeechError('speech_not_supported'), SpeechFailure.unsupported);
      expect(mapSpeechError('aborted'), isNull);
      expect(mapSpeechError('error_busy'), SpeechFailure.other);
      expect(mapSpeechError('что-то новое'), SpeechFailure.other);
    });
  });
}
