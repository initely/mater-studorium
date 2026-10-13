import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';

import '../../../helpers/fake_duel_repository.dart';

void main() {
  group('Duel.statusAt', () {
    test('до срока статус как есть', () {
      final d = duelFixture(status: DuelStatus.active);
      expect(d.statusAt(duelNow), DuelStatus.active);
      expect(
        d.statusAt(duelNow.add(const Duration(hours: 71, minutes: 59))),
        DuelStatus.active,
      );
    });

    test('после срока open и active становятся expired', () {
      final at = duelNow.add(const Duration(hours: 72));
      expect(duelFixture().statusAt(at), DuelStatus.expired);
      expect(
        duelFixture(status: DuelStatus.active).statusAt(at),
        DuelStatus.expired,
      );
    });

    test('завершённая дуэль не просрочивается', () {
      final at = duelNow.add(const Duration(days: 30));
      expect(
        duelFixture(status: DuelStatus.finished).statusAt(at),
        DuelStatus.finished,
      );
    });
  });

  test('remainingAt: не меньше нуля', () {
    final d = duelFixture();
    expect(d.remainingAt(duelNow), const Duration(hours: 72));
    expect(
      d.remainingAt(duelNow.add(const Duration(hours: 70))),
      const Duration(hours: 2),
    );
    expect(d.remainingAt(duelNow.add(const Duration(days: 9))), Duration.zero);
  });

  test('DuelStatus.fromWire', () {
    for (final s in DuelStatus.values) {
      expect(DuelStatus.fromWire(s.name), s);
    }
    expect(() => DuelStatus.fromWire('nope'), throwsStateError);
  });
}
