import 'dart:async';

import 'package:mater_studorium/features/duel/domain/duel.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/duel/domain/duel_question_picker.dart';
import 'package:mater_studorium/features/duel/domain/duel_question_source.dart';
import 'package:mater_studorium/features/duel/domain/duel_repository.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';

final duelNow = DateTime.utc(2026, 10, 13, 12);

/// Дуэль для тестов; по умолчанию — созданная только что мной, соперника нет.
Duel duelFixture({
  String id = 'duel-1',
  String? code = 'K7Q2MX',
  String deckId = 'fixture-good',
  int deckVersion = 2,
  DuelStatus status = DuelStatus.open,
  DateTime? createdAt,
  DateTime? expiresAt,
  bool isCreator = true,
  bool otherJoined = false,
  String? otherName,
  DateTime? myDoneAt,
  DateTime? otherDoneAt,
}) => Duel(
  id: id,
  code: code,
  deckId: deckId,
  deckVersion: deckVersion,
  questionIds: const ['q.1', 'q.2', 'q.3', 'q.4', 'q.5'],
  status: status,
  createdAt: createdAt ?? duelNow,
  expiresAt: expiresAt ?? duelNow.add(const Duration(hours: 72)),
  isCreator: isCreator,
  otherJoined: otherJoined,
  otherName: otherName,
  myDoneAt: myDoneAt,
  otherDoneAt: otherDoneAt,
);

/// Репозиторий дуэлей, которым тест управляет вручную.
class FakeDuelRepository implements DuelRepository {
  FakeDuelRepository({this.mineResult = const [], String? displayName})
    : name = displayName;

  List<Duel> mineResult;
  Object? mineError;

  /// Что вернёт `create` (по умолчанию — дуэль с присланными полями).
  Duel? createResult;
  Object? createError;
  Completer<void>? createGate;
  final created =
      <
        ({
          String duelId,
          String deckId,
          int deckVersion,
          List<String> questionIds,
        })
      >[];

  Duel? joinResult;
  Object? joinError;
  Completer<void>? joinGate;
  final joined = <String>[];

  Duel? getResult;
  Object? getError;
  var getCalls = 0;

  /// Ответы, которые «видит» сервер: свои и (при `withOther`) соперника.
  DuelAnswers answersResult = const DuelAnswers(mine: [], other: []);
  Object? answersError;

  /// Значения `withOther` каждого вызова `answers`.
  final answersCalls = <bool>[];

  String? name;
  Object? setNameError;
  final nameWrites = <String?>[];

  @override
  Future<Duel> create({
    required String duelId,
    required String deckId,
    required int deckVersion,
    required List<String> questionIds,
  }) async {
    created.add((
      duelId: duelId,
      deckId: deckId,
      deckVersion: deckVersion,
      questionIds: questionIds,
    ));
    await createGate?.future;
    if (createError != null) throw createError!;
    return createResult ??
        duelFixture(
          id: duelId,
          deckId: deckId,
          deckVersion: deckVersion,
        ).copyWith(questionIds: questionIds);
  }

  @override
  Future<Duel> join(String code) async {
    joined.add(code);
    await joinGate?.future;
    if (joinError != null) throw joinError!;
    return joinResult ??
        duelFixture(
          code: null,
          isCreator: false,
          otherJoined: true,
          otherName: 'Алиса',
          status: DuelStatus.active,
        );
  }

  @override
  Future<Duel?> get(String duelId) async {
    getCalls++;
    if (getError != null) throw getError!;
    return getResult;
  }

  @override
  Future<DuelAnswers> answers(String duelId, {bool withOther = false}) async {
    answersCalls.add(withOther);
    if (answersError != null) throw answersError!;
    // Как сервер при запросе только своих ответов: чужие не отдаются.
    return DuelAnswers(
      mine: answersResult.mine,
      other: withOther ? answersResult.other : const [],
    );
  }

  @override
  Future<List<Duel>> mine() async {
    if (mineError != null) throw mineError!;
    return mineResult;
  }

  @override
  Future<String?> displayName() async => name;

  @override
  Future<void> setDisplayName(String? value) async {
    nameWrites.add(value);
    if (setNameError != null) throw setNameError!;
    name = value;
  }
}

/// Вопросы колоды для дуэли: заданные вручную.
class FakeDuelQuestionSource implements DuelQuestionSource {
  FakeDuelQuestionSource({this.snapshots = const {}});

  /// `deckId` -> снимок; колоды нет — `null`.
  Map<String, DuelDeckSnapshot> snapshots;

  @override
  Future<DuelDeckSnapshot?> snapshot(String deckId) async => snapshots[deckId];
}

/// [n] вопросов, по одному на знание.
DuelDeckSnapshot snapshotOf(int n, {int version = 2}) => DuelDeckSnapshot(
  deckVersion: version,
  candidates: [
    for (var i = 1; i <= n; i++)
      DuelCandidate(questionId: 'q.$i', itemId: 'item.$i'),
  ],
);
