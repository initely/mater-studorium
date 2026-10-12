// Edge Function `grade-open-answer` (ТЗ M5, §4.2, §5.2, §5.5, ADR-9, ADR-28,
// ADR-31). Здесь только окружение и сборка зависимостей; логика — handler.ts.
// Контракт и деплой — README.md.

import { chatCompletion } from "../_shared/openrouter.ts";
import { createHandler, type HandlerConfig } from "./handler.ts";
import { DeckSource } from "./deck_source.ts";
import { SupabaseAuth, SupabaseGradingStore } from "./store.ts";

/** Модель и параметры по умолчанию — выбор T07 (ADR-9, eval/grading/REPORT.md). */
const DEFAULT_MODEL = "google/gemini-2.5-flash-lite";

function env(name: string): string | undefined {
  const v = Deno.env.get(name)?.trim();
  return v === "" ? undefined : v;
}

function readConfig(): {
  config: HandlerConfig;
  apiKey: string;
  deterministic: boolean;
} {
  const errors: string[] = [];
  const num = (name: string, def: number, integer: boolean): number => {
    const raw = env(name);
    if (raw === undefined) return def;
    const n = Number(raw);
    if (!Number.isFinite(n) || n < 0 || (integer && !Number.isInteger(n))) {
      errors.push(name);
      return def;
    }
    return n;
  };
  const apiKey = env("OPENROUTER_API_KEY") ?? "";
  if (apiKey === "") errors.push("OPENROUTER_API_KEY");
  const config: HandlerConfig = {
    model: env("GRADING_MODEL") ?? DEFAULT_MODEL,
    configError: null,
    limits: {
      callLimit: num("GRADING_DAILY_LIMIT", 30, true),
      requestLimit: num("GRADING_DAILY_REQUEST_LIMIT", 300, true),
      budgetUsd: num("DAILY_BUDGET_USD", 1, false),
      // Верхняя оценка двух попыток (MAX_MODEL_CALLS); средний вызов ≈ $0.0002.
      reserveUsd: num("GRADING_RESERVE_USD", 0.002, false),
      unknownCostUsd: num("GRADING_UNKNOWN_COST_USD", 0.001, false),
    },
    allowedOrigins: (env("GRADING_ALLOWED_ORIGINS") ?? "")
      .split(",").map((s) => s.trim()).filter((s) => s !== ""),
    modelDeadlineMs: num("GRADING_MODEL_DEADLINE_MS", 12_000, true),
  };
  if (config.limits.reserveUsd <= 0) errors.push("GRADING_RESERVE_USD");
  // Имена переменных, а не значения: значения могут быть секретами.
  if (errors.length > 0) config.configError = `env: ${errors.join(", ")}`;
  // temperature 0 и seed: у gemini есть, у claude-haiku на OpenRouter нет
  // (с require_parameters запрос тогда не уйдёт ни одному провайдеру).
  const deterministic = env("GRADING_DETERMINISTIC") !== "false";
  return { config, apiKey, deterministic };
}

const supabaseUrl = env("SUPABASE_URL") ?? "";
const anonKey = env("SUPABASE_ANON_KEY") ?? "";
const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const { config, apiKey, deterministic } = readConfig();
if (supabaseUrl === "" || anonKey === "" || serviceKey === "") {
  config.configError = `${config.configError ?? "env:"} SUPABASE_*`;
}
const supabase = { supabaseUrl, anonKey, serviceKey };

const handler = createHandler({
  config,
  auth: new SupabaseAuth(supabase),
  decks: new DeckSource(supabase),
  store: new SupabaseGradingStore(supabase),
  model: (messages, format, timeoutMs) =>
    chatCompletion({
      apiKey,
      model: config.model,
      messages,
      responseFormat: format,
      temperature: deterministic ? 0 : undefined,
      seed: deterministic ? 7 : undefined,
      maxTokens: 800,
      timeoutMs,
      title: "Mater Studorium grade-open-answer",
    }),
});

Deno.serve(handler);
