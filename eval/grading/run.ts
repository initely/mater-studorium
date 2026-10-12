// Eval оценки открытых ответов (T07, ТЗ §4.2, §5.2, R1).
//
//   deno run -A eval/grading/run.ts --model <openrouter-id> [--limit N] [--out file]
//     [--dry-run] [--no-reasoning] [--temperature 0] [--seed 7] [--only id,id]
//
// Ключ: OPENROUTER_API_KEY из окружения (в файлы и вывод не пишется).
// Промпт, разбор и подсчёт балла — тот же supabase/functions/_shared/grading.ts,
// что и в Edge Function. Результат: eval/grading/runs/<дата>_<модель>.json.

import {
  buildMessages,
  type ChatMessage,
  DEFAULT_THRESHOLDS,
  gradeOpenAnswer,
  type GradeResult,
  type InputMode,
  type OpenQuestion,
  PROMPT_VERSION,
  responseFormat,
  type Verdict,
} from "../../supabase/functions/_shared/grading.ts";
import {
  chatCompletion,
  type CompletionUsage,
  OpenRouterError,
} from "../../supabase/functions/_shared/openrouter.ts";

const DIR = new URL(".", import.meta.url);

export interface EvalCase {
  id: string;
  question_id: string;
  kind:
    | "correct"
    | "paraphrase"
    | "partial"
    | "incorrect"
    | "asr"
    | "injection"
    | "garbage";
  input_mode: InputMode;
  answer_text: string;
  expected_verdict: Exclude<Verdict, "unsure">;
  labeled_by: string;
  needs_human_review: boolean;
  note?: string;
}

export interface CallRecord {
  latency_ms: number;
  usage: CompletionUsage | null;
  provider?: string;
  error?: string;
}

export interface CaseResult {
  id: string;
  question_id: string;
  kind: EvalCase["kind"];
  expected: EvalCase["expected_verdict"];
  /** "error" — сеть/провайдер не ответили (в Edge Function это фолбэк на самооценку). */
  predicted: Verdict | "error";
  grade?: GradeResult;
  calls: CallRecord[];
  network_retries: number;
  wall_ms: number;
  error?: string;
}

export const CORE_KINDS = new Set([
  "correct",
  "paraphrase",
  "partial",
  "incorrect",
  "asr",
]);

export function loadQuestions(): {
  lang: string;
  byId: Map<string, OpenQuestion>;
} {
  const raw = JSON.parse(
    Deno.readTextFileSync(new URL("questions.json", DIR)),
  );
  const byId = new Map<string, OpenQuestion>();
  for (const q of raw.questions) {
    byId.set(q.id, {
      id: q.id,
      prompt: q.prompt,
      reference_answer: q.payload.reference_answer,
      rubric: q.payload.rubric,
    });
  }
  return { lang: raw.lang, byId };
}

export function loadCases(): EvalCase[] {
  return Deno.readTextFileSync(new URL("cases.jsonl", DIR))
    .split("\n")
    .filter((l) => l.trim())
    .map((l) => JSON.parse(l));
}

// ---------------------------------------------------------------------------
// Метрики (чистые функции, переиспользуются в tune.ts)

export function percentile(values: number[], p: number): number | null {
  if (values.length === 0) return null;
  const s = [...values].sort((a, b) => a - b);
  // nearest-rank
  const rank = Math.ceil((p / 100) * s.length);
  return s[Math.min(s.length, Math.max(1, rank)) - 1];
}

const RANK: Record<string, number> = { incorrect: 0, partial: 1, correct: 2 };

/** Модель «не поддалась» инъекции: вердикт не выше ожидаемого (unsure/error — не поддалась). */
export function resistedInjection(
  expected: string,
  predicted: string,
): boolean {
  if (!(predicted in RANK)) return true;
  return RANK[predicted] <= RANK[expected];
}

export function summarize(results: CaseResult[]) {
  const LABELS = ["correct", "partial", "incorrect", "unsure", "error"];
  const agreement = (rs: CaseResult[]) => {
    const ok = rs.filter((r) => r.predicted === r.expected).length;
    return {
      agree: ok,
      total: rs.length,
      rate: rs.length ? ok / rs.length : 0,
    };
  };
  const confusion: Record<string, Record<string, number>> = {};
  for (const e of ["correct", "partial", "incorrect"]) {
    confusion[e] = Object.fromEntries(LABELS.map((l) => [l, 0]));
  }
  for (const r of results) confusion[r.expected][r.predicted]++;

  const byKind: Record<string, ReturnType<typeof agreement>> = {};
  for (const k of new Set(results.map((r) => r.kind))) {
    byKind[k] = agreement(results.filter((r) => r.kind === k));
  }

  const calls = results.flatMap((r) => r.calls);
  const okCalls = calls.filter((c) => !c.error && c.usage);
  const costs = okCalls.map((c) => c.usage!.cost).filter((c): c is number =>
    c !== null
  );
  const modelGraded = results.filter((r) => r.calls.length > 0);
  const gradingCosts = modelGraded.map((r) =>
    r.calls.reduce((s, c) => s + (c.usage?.cost ?? 0), 0)
  );
  const invalidOutputs = results.reduce(
    (s, r) => s + (r.grade?.parse_errors.length ?? 0),
    0,
  );
  const injections = results.filter((r) => r.kind === "injection");
  const modelVerdictAgree =
    results.filter((r) => r.grade?.model_verdict === r.expected).length;
  const mean = (xs: number[]) =>
    xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null;

  return {
    agreement_core: agreement(results.filter((r) => CORE_KINDS.has(r.kind))),
    agreement_all: agreement(results),
    agreement_by_kind: byKind,
    /** Согласие «сырого» verdict модели (без серверного подсчёта), для сравнения. */
    model_own_verdict_agreement_all: {
      agree: modelVerdictAgree,
      total: modelGraded.length,
    },
    confusion_expected_x_predicted: confusion,
    injections: {
      total: injections.length,
      resisted:
        injections.filter((r) => resistedInjection(r.expected, r.predicted))
          .length,
      exact: injections.filter((r) => r.predicted === r.expected).length,
      cases: injections.map((r) => ({
        id: r.id,
        expected: r.expected,
        predicted: r.predicted,
        model_verdict: r.grade?.model_verdict,
      })),
    },
    api_calls: calls.length,
    api_errors: calls.filter((c) => c.error).length,
    network_retries: results.reduce((s, r) => s + r.network_retries, 0),
    gradings_without_model: results.filter((r) => r.calls.length === 0).length,
    gradings_with_invalid_retry:
      results.filter((r) => (r.grade?.attempts ?? 0) > 1).length,
    invalid_outputs: invalidOutputs,
    invalid_output_rate: okCalls.length ? invalidOutputs / okCalls.length : 0,
    unsure_after_retry:
      results.filter((r) => r.grade?.rule === "invalid_output").length,
    errors: results.filter((r) => r.predicted === "error").length,
    cost_usd: {
      total: costs.reduce((a, b) => a + b, 0),
      per_call_mean: mean(costs),
      per_call_max: costs.length ? Math.max(...costs) : null,
      per_grading_mean: mean(gradingCosts),
      calls_without_cost: okCalls.length - costs.length,
    },
    tokens_per_call_mean: {
      prompt: mean(okCalls.map((c) => c.usage!.prompt_tokens)),
      completion: mean(okCalls.map((c) => c.usage!.completion_tokens)),
      reasoning: mean(okCalls.map((c) => c.usage!.reasoning_tokens)),
    },
    latency_ms: {
      call_p50: percentile(okCalls.map((c) => c.latency_ms), 50),
      call_p95: percentile(okCalls.map((c) => c.latency_ms), 95),
      call_max: okCalls.length
        ? Math.max(...okCalls.map((c) => c.latency_ms))
        : null,
      grading_p50: percentile(modelGraded.map((r) => r.wall_ms), 50),
      grading_p95: percentile(modelGraded.map((r) => r.wall_ms), 95),
    },
    providers: [...new Set(calls.map((c) => c.provider).filter(Boolean))],
  };
}

// ---------------------------------------------------------------------------
// CLI

function parseArgs(args: string[]) {
  const o: Record<string, string | boolean> = {};
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (!a.startsWith("--")) throw new Error(`unexpected argument: ${a}`);
    const key = a.slice(2);
    const next = args[i + 1];
    if (next === undefined || next.startsWith("--")) o[key] = true;
    else {
      o[key] = next;
      i++;
    }
  }
  return o;
}

async function modelInfo(model: string) {
  const res = await fetch("https://openrouter.ai/api/v1/models");
  const { data } = await res.json();
  const m = (data as {
    id: string;
    pricing: Record<string, string>;
    supported_parameters?: string[];
  }[]).find((x) => x.id === model);
  if (!m) throw new Error(`model not found on OpenRouter: ${model}`);
  return m;
}

async function main() {
  const args = parseArgs(Deno.args);
  const model = args.model;
  if (typeof model !== "string") {
    console.error(
      "usage: deno run -A eval/grading/run.ts --model <id> [--limit N] [--out file] [--dry-run] [--no-reasoning] [--only id,id]",
    );
    Deno.exit(2);
  }
  const { lang, byId } = loadQuestions();
  let cases = loadCases();
  if (typeof args.only === "string") {
    const only = new Set(args.only.split(","));
    cases = cases.filter((c) => only.has(c.id));
  }
  if (typeof args.limit === "string") {
    cases = cases.slice(0, Number(args.limit));
  }
  for (const c of cases) {
    if (!byId.has(c.question_id)) {
      throw new Error(`unknown question ${c.question_id}`);
    }
  }

  if (args["dry-run"]) {
    const c = cases[0];
    const msgs = buildMessages(
      byId.get(c.question_id)!,
      c.answer_text,
      c.input_mode,
      lang,
    );
    for (const m of msgs) console.log(`--- ${m.role} ---\n${m.content}`);
    console.log("--- response_format ---");
    console.log(JSON.stringify(responseFormat(byId.get(c.question_id)!)));
    const chars = msgs.reduce((s, m) => s + m.content.length, 0);
    console.log(`\n${cases.length} cases, first prompt ${chars} chars`);
    return;
  }

  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    console.error("OPENROUTER_API_KEY is not set");
    Deno.exit(2);
  }
  const info = await modelInfo(model);
  const supported = new Set(info.supported_parameters ?? []);
  const temperature = Number(args.temperature ?? 0);
  const seed = Number(args.seed ?? 7);
  const params = {
    temperature: supported.has("temperature") ? temperature : undefined,
    seed: supported.has("seed") ? seed : undefined,
    reasoning: args["no-reasoning"] ? { enabled: false } : undefined,
    max_tokens: 800,
    timeout_ms: 15_000,
    response_format: "json_schema (strict)",
    require_parameters: true,
  };

  const startedAt = new Date().toISOString();
  const results: CaseResult[] = [];
  for (const [i, c] of cases.entries()) {
    const question = byId.get(c.question_id)!;
    const calls: CallRecord[] = [];
    let networkRetries = 0;
    const complete = async (
      messages: ChatMessage[],
      format: ReturnType<typeof responseFormat>,
    ) => {
      for (let attempt = 0;; attempt++) {
        const started = performance.now();
        try {
          const r = await chatCompletion({
            apiKey,
            model,
            messages,
            responseFormat: format,
            temperature: params.temperature,
            seed: params.seed,
            reasoning: params.reasoning,
            maxTokens: params.max_tokens,
            timeoutMs: params.timeout_ms,
            title: "Mater Studorium eval (T07)",
          });
          calls.push({
            latency_ms: Math.round(r.latencyMs),
            usage: r.usage,
            provider: r.provider,
          });
          return r.content;
        } catch (e) {
          const err = e instanceof OpenRouterError ? e : null;
          calls.push({
            latency_ms: Math.round(performance.now() - started),
            usage: null,
            error: err ? err.message : String(e).slice(0, 200),
          });
          if (err?.retryable && attempt === 0) {
            networkRetries++;
            await new Promise((r) => setTimeout(r, 2000));
            continue;
          }
          throw e;
        }
      }
    };
    const started = performance.now();
    let grade: GradeResult | undefined;
    let error: string | undefined;
    try {
      grade = await gradeOpenAnswer({
        question,
        answer: c.answer_text,
        inputMode: c.input_mode,
        lang,
        thresholds: DEFAULT_THRESHOLDS,
      }, complete);
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
    const r: CaseResult = {
      id: c.id,
      question_id: c.question_id,
      kind: c.kind,
      expected: c.expected_verdict,
      predicted: grade?.verdict ?? "error",
      grade,
      calls,
      network_retries: networkRetries,
      wall_ms: Math.round(performance.now() - started),
      error,
    };
    results.push(r);
    const cost = calls.reduce((s, x) => s + (x.usage?.cost ?? 0), 0);
    console.log(
      `${String(i + 1).padStart(2)}/${cases.length} ${
        r.predicted === r.expected ? "OK  " : "DIFF"
      } ${c.id.padEnd(34)} exp=${r.expected.padEnd(9)} got=${
        r.predicted.padEnd(9)
      } score=${grade?.score ?? "-"} model=${
        grade?.model_verdict ?? "-"
      } ${r.wall_ms}ms $${cost.toFixed(6)}${error ? " ERR " + error : ""}`,
    );
  }

  const summary = summarize(results);
  const out = {
    model,
    started_at: startedAt,
    prompt_version: PROMPT_VERSION,
    thresholds: DEFAULT_THRESHOLDS,
    params,
    pricing_per_token: {
      prompt: info.pricing.prompt,
      completion: info.pricing.completion,
    },
    labels: "ai-draft (needs human review)",
    summary,
    results,
  };
  const outPath = typeof args.out === "string" ? args.out : new URL(
    `runs/${out.started_at.slice(0, 19).replaceAll(":", "")}_${
      model.replaceAll("/", "_")
    }.json`,
    DIR,
  );
  await Deno.mkdir(new URL("runs/", DIR), { recursive: true });
  await Deno.writeTextFile(outPath, JSON.stringify(out, null, 1) + "\n");
  console.log(JSON.stringify(summary, null, 1));
  console.log(`saved: ${outPath instanceof URL ? outPath.pathname : outPath}`);
}

if (import.meta.main) await main();
