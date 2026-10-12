// Подбор порогов §4.2 по сохранённым прогонам, без новых вызовов модели.
//
//   deno run -A eval/grading/tune.ts eval/grading/runs/<a>.json [<b>.json ...]
//
// Для каждой пары (correct, partial) пересчитывает вердикт тем же scoreGrade
// по сохранённым статусам пунктов и печатает согласие с разметкой (ядро 40
// кейсов и все). Кейсы без ответа модели (короткий ответ, невалидный JSON,
// сетевая ошибка) сохраняют свой вердикт.

import {
  scoreGrade,
  type Thresholds,
} from "../../supabase/functions/_shared/grading.ts";
import { type CaseResult, CORE_KINDS, loadQuestions } from "./run.ts";

const { byId } = loadQuestions();

function verdictsAt(results: CaseResult[], t: Thresholds) {
  return results.map((r) => {
    const g = r.grade;
    if (!g || !g.model_verdict) return r.predicted;
    const rubric = byId.get(r.question_id)!.rubric;
    return scoreGrade(
      {
        points: g.points.map((p) => ({ ...p, evidence: "" })),
        contradiction: g.contradiction!,
        verdict: g.model_verdict,
      },
      rubric,
      t,
    ).verdict;
  });
}

function agreement(results: CaseResult[], t: Thresholds) {
  const v = verdictsAt(results, t);
  let core = 0;
  let all = 0;
  results.forEach((r, i) => {
    if (v[i] !== r.expected) return;
    all++;
    if (CORE_KINDS.has(r.kind)) core++;
  });
  return { core, all };
}

const runs = Deno.args.map((p) => {
  const d = JSON.parse(Deno.readTextFileSync(p));
  return { model: d.model as string, results: d.results as CaseResult[] };
});
if (runs.length === 0) {
  console.error("usage: deno run -A eval/grading/tune.ts <run.json> ...");
  Deno.exit(2);
}

const grid: Thresholds[] = [];
for (let c = 50; c <= 95; c += 5) {
  for (let p = 20; p < c; p += 5) {
    grid.push({ correct: c / 100, partial: p / 100 });
  }
}

const rows = grid.map((t) => {
  const per = runs.map((r) => agreement(r.results, t));
  return { t, per, coreSum: per.reduce((s, x) => s + x.core, 0) };
});
rows.sort((a, b) => b.coreSum - a.coreSum || b.t.correct - a.t.correct);

const nCore = runs[0].results.filter((r) => CORE_KINDS.has(r.kind)).length;
const nAll = runs[0].results.length;
const fmt = (row: (typeof rows)[number]) =>
  `correct≥${row.t.correct.toFixed(2)} partial≥${row.t.partial.toFixed(2)}  ` +
  row.per.map((x, i) =>
    `${runs[i].model}: ${x.core}/${nCore} (${
      (100 * x.core / nCore).toFixed(1)
    }%) all ${x.all}/${nAll}`
  ).join("  |  ");

const at = (c: number, p: number) =>
  rows.find((r) => r.t.correct === c && r.t.partial === p)!;
console.log("assumption §4.2 (0.80 / 0.50):\n  " + fmt(at(0.8, 0.5)));
console.log("chosen in T07 (0.70 / 0.35):\n  " + fmt(at(0.7, 0.35)));
console.log("top 15 by summed core agreement:");
for (const row of rows.slice(0, 15)) console.log("  " + fmt(row));

// Leave-one-question-out: пороги подбираются на 7 вопросах, проверяются на
// 8-м. Оценка без подгонки под те же кейсы (разметка всё равно черновая).
// При равенстве берутся более строгие пороги (порядок сортировки grid).
console.log("leave-one-question-out CV (core cases):");
const strict = [...grid].sort((a, b) =>
  b.correct - a.correct || b.partial - a.partial
);
for (const run of runs) {
  const core = run.results.filter((r) => CORE_KINDS.has(r.kind));
  let agree = 0;
  const picked: string[] = [];
  for (const qid of new Set(core.map((r) => r.question_id))) {
    const train = core.filter((r) => r.question_id !== qid);
    const test = core.filter((r) => r.question_id === qid);
    let best = strict[0];
    let bestScore = -1;
    for (const t of strict) {
      const s = agreement(train, t).core;
      if (s > bestScore) [best, bestScore] = [t, s];
    }
    agree += agreement(test, best).core;
    picked.push(`${best.correct}/${best.partial}`);
  }
  console.log(
    `  ${run.model}: ${agree}/${core.length} (${
      (100 * agree / core.length).toFixed(1)
    }%), thresholds per fold: ${picked.join(" ")}`,
  );
}
