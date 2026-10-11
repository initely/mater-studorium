import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/utils/stable_seed.dart';

void main() {
  test('зерно зависит только от строки и стабильно между запусками', () {
    // Значение зафиксировано: если формула изменится, порядок вариантов у
    // всех пользователей сменится.
    expect(stableSeed('q1|2026-10-11'), 614645550);
    expect(stableSeed('q1|2026-10-11'), stableSeed('q1|2026-10-11'));
  });

  test('разные ключи дают разные зёрна', () {
    expect(stableSeed('q1|2026-10-11'), isNot(stableSeed('q1|2026-10-12')));
    expect(stableSeed('q1|2026-10-11'), isNot(stableSeed('q2|2026-10-11')));
  });

  test('зерно неотрицательное и умещается в 31 бит', () {
    for (final key in [
      '',
      'a',
      'infosec.xss.reflected.q1|2026-10-11',
      'я' * 200,
    ]) {
      expect(stableSeed(key), inInclusiveRange(0, 0x7fffffff));
    }
  });
}
