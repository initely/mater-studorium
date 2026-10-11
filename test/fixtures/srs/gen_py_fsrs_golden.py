"""Эталонные траектории py-fsrs 6.3.2 для тестов scheduler.dart (T11).

Каждый шаг: (оценка, сдвиг времени ответа относительно due предыдущего
шага в секундах). Первый ответ — в момент T0.

Перегенерация (нужна только при смене эталона):
    python3 -m venv /tmp/pyfsrs && /tmp/pyfsrs/bin/pip install fsrs==6.3.2
    /tmp/pyfsrs/bin/python test/fixtures/srs/gen_py_fsrs_golden.py \
        > test/fixtures/srs/py_fsrs_6_3_2.json
"""
import json
from datetime import datetime, timedelta, timezone

import fsrs
from fsrs import Card, Rating, Scheduler

T0 = datetime(2026, 10, 11, 12, 0, tzinfo=timezone.utc)
DAY = 86400

SCENARIOS = {
    "on_time_mixed": [(3, 0), (3, 0), (3, 0), (3, 0), (1, 0), (3, 0), (3, 0), (2, 0), (4, 0), (3, 0)],
    "learning_short_term": [(1, 0), (2, 0), (1, 0), (2, 0), (3, 0), (3, 0)],
    "late_reviews": [(3, 0), (3, 3 * DAY), (4, 10 * DAY), (2, 30 * DAY), (3, 5 * DAY + 3600)],
    "early_and_same_day": [(3, 0), (3, -DAY), (3, -3600 * 30), (2, -3600 * 50), (3, 0), (4, -DAY * 2)],
    "lapse_relearn_next_day": [(4, 0), (3, 0), (1, 0), (3, DAY), (1, 0), (1, 3600), (2, 0), (3, 2 * DAY)],
    "learning_after_gap": [(1, 0), (3, 3 * DAY), (3, 0)],
    "all_easy": [(4, 0)] * 12,
    "all_hard": [(2, 0)] * 8,
}

CAPPED = {"capped_30_days": ([(4, 0)] * 6, 30)}


def run(steps, max_interval=36500):
    s = Scheduler(
        learning_steps=(timedelta(minutes=10),),
        relearning_steps=(timedelta(minutes=10),),
        enable_fuzzing=False,
        desired_retention=0.9,
        maximum_interval=max_interval,
    )
    card = Card(card_id=1, due=T0)
    out = []
    for rating, shift in steps:
        now = card.due + timedelta(seconds=shift)
        card, _ = s.review_card(card, Rating(rating), now)
        out.append(
            {
                "rating": rating,
                "at": now.isoformat().replace("+00:00", "Z"),
                "state": card.state.name.lower(),
                "s": card.stability,
                "d": card.difficulty,
                "due": card.due.isoformat().replace("+00:00", "Z"),
            }
        )
    return out


result = {"source": f"py-fsrs {fsrs.__version__ if hasattr(fsrs, '__version__') else '6.3.2'}", "scenarios": {}}
for name, steps in SCENARIOS.items():
    result["scenarios"][name] = {"maxInterval": 36500, "steps": run(steps)}
for name, (steps, cap) in CAPPED.items():
    result["scenarios"][name] = {"maxInterval": cap, "steps": run(steps, cap)}
print(json.dumps(result, indent=1))
