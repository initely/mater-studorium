// Фейки для формата `open` (T16): оценка на сервере, диктовка, согласие.
import 'dart:async';

import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/grading/domain/grading_repository.dart';
import 'package:mater_studorium/features/grading/domain/llm_consent.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:mater_studorium/features/speech/domain/speech_service.dart';

/// Ответ сервера для тестов; значения по умолчанию — `partial` с одним
/// упущенным пунктом (как в README функции).
OpenGrade fakeGrade({
  GradeVerdict verdict = GradeVerdict.partial,
  double score = 0.5,
  List<GradedPoint>? points,
  List<MissedPoint>? missed,
  String feedback = 'Не объяснено, зачем нужно экранирование.',
  GradeOrigin origin = GradeOrigin.llm,
  bool cached = false,
  int? remainingQuota = 27,
}) => OpenGrade(
  verdict: verdict,
  score: score,
  points:
      points ??
      const [
        GradedPoint(id: 'p1', status: PointStatus.hit),
        GradedPoint(id: 'p2', status: PointStatus.partial),
        GradedPoint(id: 'p3', status: PointStatus.miss),
      ],
  missed:
      missed ??
      const [
        MissedPoint(
          id: 'p2',
          text: 'Скрипт выполняется в браузере жертвы (сервер)',
          status: PointStatus.partial,
          required: false,
        ),
        MissedPoint(
          id: 'p3',
          text: 'Защита: экранирование вывода (сервер)',
          status: PointStatus.miss,
          required: true,
        ),
      ],
  feedback: feedback,
  origin: origin,
  cached: cached,
  remainingQuota: remainingQuota,
);

/// Репозиторий оценки: отвечает по очереди заготовленным (значение или
/// ошибка), считает вызовы и запоминает запросы. [gate] задерживает ответ до
/// ручного завершения (двойной тап, поворот во время проверки).
class FakeGradingRepository implements GradingRepository {
  FakeGradingRepository([Iterable<Object> replies = const []])
    : _replies = [...replies];

  final List<Object> _replies;
  final List<GradeRequest> requests = [];
  Completer<void>? gate;

  int get calls => requests.length;

  void enqueue(Object reply) => _replies.add(reply);

  @override
  Future<OpenGrade> grade(GradeRequest request) async {
    requests.add(request);
    final g = gate;
    if (g != null) await g.future;
    final reply = _replies.isEmpty
        ? throw StateError('нет заготовленного ответа')
        : _replies.removeAt(0);
    if (reply is AppError) throw reply;
    return reply as OpenGrade;
  }
}

class FakeLlmConsentRepository implements LlmConsentRepository {
  FakeLlmConsentRepository([this.value = LlmConsent.unknown]);

  LlmConsent value;
  int saves = 0;

  @override
  Future<LlmConsent> load() async => value;

  @override
  Future<void> save(LlmConsent consent) async {
    saves++;
    value = consent;
  }
}

/// Диктовка: тест сам «говорит» через [say], завершает через [finish] и
/// ломает сессию через [fail].
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.supportValue = SpeechSupport.available});

  SpeechSupport supportValue;
  int listens = 0;
  int stops = 0;
  int cancels = 0;
  String? lastLang;
  StreamController<SpeechUpdate>? _controller;

  /// Если задан, `listen` сразу падает с этой причиной (после первого кадра).
  SpeechFailure? failOnListen;

  bool get listening => _controller != null && !_controller!.isClosed;

  @override
  Future<SpeechSupport> support() async => supportValue;

  @override
  Stream<SpeechUpdate> listen({required String lang}) {
    listens++;
    lastLang = lang;
    final c = StreamController<SpeechUpdate>(onCancel: () {});
    _controller = c;
    final failure = failOnListen;
    if (failure != null) {
      scheduleMicrotask(() {
        c.addError(SpeechException(failure));
        c.close();
      });
    }
    return c.stream;
  }

  void say(String text, {bool isFinal = false}) =>
      _controller!.add(SpeechUpdate(text, isFinal: isFinal));

  Future<void> finish() async => _controller!.close();

  void fail(SpeechFailure failure) {
    _controller!.addError(SpeechException(failure));
    _controller!.close();
  }

  @override
  Future<void> stop() async {
    stops++;
    // Платформа присылает итог и закрывает поток.
    unawaited(_controller?.close());
  }

  @override
  Future<void> cancel() async {
    cancels++;
    unawaited(_controller?.close());
  }
}

class FakeAppSettingsOpener implements AppSettingsOpener {
  FakeAppSettingsOpener({this.isSupported = true});

  @override
  final bool isSupported;
  int opened = 0;

  @override
  Future<void> openAppSettings() async => opened++;
}
