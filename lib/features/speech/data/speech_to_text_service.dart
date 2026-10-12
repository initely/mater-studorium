import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/speech_service.dart';

/// Сколько максимум длится одна сессия диктовки (ответ на `open` — 1–3
/// предложения; платформа может оборвать раньше).
const Duration kSpeechListenFor = Duration(seconds: 60);

/// Пауза в речи, после которой сессия заканчивается сама.
const Duration kSpeechPauseFor = Duration(seconds: 5);

/// Сколько ждём итоговый результат после `notListening`, прежде чем закрыть
/// поток сами (платформа иногда не присылает `done`).
const Duration kSpeechDoneGrace = Duration(seconds: 3);

/// [SpeechService] поверх пакета `speech_to_text` (Android, web через Web
/// Speech API; ADR-32).
///
/// Звук не сохраняется и не уходит приложением никуда: берётся только
/// `recognizedWords`. Распознаёт платформенный сервис (на Android и в Chrome он
/// может работать через сеть: это политика платформы, не приложения).
class SpeechToTextService implements SpeechService {
  SpeechToTextService({SpeechToText? engine}) : _stt = engine ?? SpeechToText();

  final SpeechToText _stt;
  bool _initialized = false;
  bool _unsupported = false;
  StreamController<SpeechUpdate>? _session;
  Timer? _graceTimer;

  @override
  Future<SpeechSupport> support() async {
    if (_unsupported) return SpeechSupport.unsupported;
    if (_initialized) return SpeechSupport.available;
    // На web инициализация не просит разрешения и сразу отвечает, есть ли
    // Web Speech API. На Android она показала бы системный диалог, поэтому
    // там решаем при первом запуске диктовки.
    if (kIsWeb && !await _ensureInitialized()) {
      return SpeechSupport.unsupported;
    }
    return SpeechSupport.available;
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    final ok = await _stt.initialize(
      onError: _onError,
      onStatus: _onStatus,
      finalTimeout: const Duration(seconds: 2),
    );
    _initialized = ok;
    return ok;
  }

  @override
  Stream<SpeechUpdate> listen({required String lang}) {
    late final StreamController<SpeechUpdate> session;
    session = StreamController<SpeechUpdate>(
      // Слушатель ушёл (экран закрыт): остановить распознавание.
      onCancel: () {
        if (_session == session) unawaited(cancel());
      },
    );
    unawaited(_close(_session));
    _session = session;
    unawaited(_start(session, lang));
    return session.stream;
  }

  Future<void> _start(
    StreamController<SpeechUpdate> session,
    String lang,
  ) async {
    try {
      if (_unsupported || !await _ensureInitialized()) {
        // На Android `initialize` возвращает false и при отказе в разрешении,
        // и без сервиса распознавания: различаем по разрешению.
        final denied = !kIsWeb && !await _stt.hasPermission;
        if (!denied) _unsupported = true;
        _fail(
          session,
          denied ? SpeechFailure.permissionDenied : SpeechFailure.unsupported,
        );
        return;
      }
      final localeId = await _localeFor(lang);
      if (localeId == null) {
        _fail(session, SpeechFailure.languageUnavailable);
        return;
      }
      if (_session != session) return; // уже отменена
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          if (!session.isClosed) {
            session.add(
              SpeechUpdate(r.recognizedWords, isFinal: r.finalResult),
            );
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: localeId,
          listenFor: kSpeechListenFor,
          pauseFor: kSpeechPauseFor,
        ),
      );
    } on Object {
      _fail(session, SpeechFailure.other);
    }
  }

  Future<String?> _localeFor(String lang) async {
    if (kIsWeb) return speechLocaleId(lang, web: true);
    final available = (await _stt.locales()).map((l) => l.localeId).toList();
    if (available.isEmpty) return speechLocaleId(lang);
    return pickSpeechLocale(lang, available);
  }

  void _onStatus(String status) {
    final session = _session;
    if (session == null) return;
    if (status == SpeechToText.doneStatus) {
      unawaited(_close(session));
    } else if (status == SpeechToText.notListeningStatus) {
      _graceTimer?.cancel();
      _graceTimer = Timer(kSpeechDoneGrace, () => unawaited(_close(session)));
    }
  }

  void _onError(SpeechRecognitionError error) {
    final session = _session;
    if (session == null) return;
    final failure = mapSpeechError(error.errorMsg);
    // `null` — отмена самим пользователем: не ошибка.
    if (failure == null) return;
    _fail(session, failure);
  }

  void _fail(StreamController<SpeechUpdate> session, SpeechFailure failure) {
    if (session.isClosed) return;
    session.addError(SpeechException(failure));
    unawaited(_close(session));
  }

  Future<void> _close(StreamController<SpeechUpdate>? session) async {
    if (session == null) return;
    if (_session == session) {
      _session = null;
      _graceTimer?.cancel();
    }
    if (!session.isClosed) await session.close();
  }

  @override
  Future<void> stop() async {
    final session = _session;
    if (session == null) return;
    try {
      await _stt.stop();
    } on Object {
      // Сессия закрывается в любом случае.
    }
    // Итоговый результат мог прийти до этого вызова или придёт по `done`;
    // `done` закроет поток, а если не придёт, закроет таймер.
    _graceTimer?.cancel();
    _graceTimer = Timer(kSpeechDoneGrace, () => unawaited(_close(session)));
  }

  @override
  Future<void> cancel() async {
    final session = _session;
    try {
      if (_initialized) await _stt.cancel();
    } on Object {
      // Нечего отменять.
    }
    await _close(session);
  }
}

/// Код платформенной ошибки `speech_to_text` → причина; `null` — не ошибка
/// (прерывание самим пользователем). Android: `error_*`, web: коды Web Speech
/// API.
SpeechFailure? mapSpeechError(String errorMsg) {
  final e = errorMsg.toLowerCase();
  if (e == 'aborted' || e == 'error_aborted') return null;
  if (e.contains('permission') ||
      e == 'not-allowed' ||
      e == 'service-not-allowed') {
    return SpeechFailure.permissionDenied;
  }
  if (e == 'error_no_match' ||
      e == 'error_speech_timeout' ||
      e == 'no-speech' ||
      e == 'nomatch') {
    return SpeechFailure.noSpeech;
  }
  if (e.contains('network') || e == 'error_server_disconnected') {
    return SpeechFailure.network;
  }
  if (e.contains('language')) return SpeechFailure.languageUnavailable;
  if (e == 'speech_not_supported' || e == 'not supported') {
    return SpeechFailure.unsupported;
  }
  return SpeechFailure.other;
}

/// Идентификатор локали распознавания по коду языка колоды: `ru` → `ru_RU`
/// (на web `ru-RU`, формат BCP 47).
String speechLocaleId(String lang, {bool web = false}) {
  final id = switch (lang.toLowerCase()) {
    'ru' => 'ru_RU',
    'en' => 'en_US',
    final other => other,
  };
  return web ? id.replaceAll('_', '-') : id;
}

/// Локаль из списка устройства для языка колоды: точная `ru_RU`, иначе любая
/// с тем же языком; `null`, если языка нет.
String? pickSpeechLocale(String lang, List<String> available) {
  String norm(String s) => s.replaceAll('-', '_').toLowerCase();
  final wanted = norm(speechLocaleId(lang));
  final language = norm(lang).split('_').first;
  String? sameLanguage;
  for (final id in available) {
    final n = norm(id);
    if (n == wanted) return id;
    if (sameLanguage == null && n.split('_').first == language) {
      sameLanguage = id;
    }
  }
  return sameLanguage;
}
