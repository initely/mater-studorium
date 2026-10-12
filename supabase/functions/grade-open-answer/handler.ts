// Обработчик `grade-open-answer` (ТЗ M5, §4.2, §5.2, §5.5, ADR-31) на
// внедрённых зависимостях: Auth, колода, хранилище, вызов модели, часы и лог.
// Сеть и Deno.env — только в index.ts, поэтому всё здесь проверяется
// deno-тестами без сети.
//
// Порядок: CORS → метод → Authorization есть → тело (размер, JSON, поля) →
// JWT в Auth → настройка → колода и вопрос (с RLS пользователя) → короткий
// ответ (без модели) → кэш → лимиты → модель → кэш, журнал → ответ.

import {
  type CompleteFn,
  DEFAULT_THRESHOLDS,
  gradeOpenAnswer,
  type GradeResult,
  isTooShort,
  normalizeAnswer,
  type OpenQuestion,
  PROMPT_VERSION,
  sanitizeAnswer,
  scoreGrade,
  suggestedRating,
  type Thresholds,
} from "../_shared/grading.ts";
import {
  type CompletionResult,
  OpenRouterError,
} from "../_shared/openrouter.ts";
import {
  type ErrorBody,
  type ErrorCode,
  type GradeRequest,
  type GradeResponse,
  MAX_BODY_BYTES,
  type MissedPoint,
  parseGradeRequest,
} from "./contract.ts";
import { DeckInvalidError, type DeckLookup } from "./deck_source.ts";
import type {
  Authenticator,
  CachedGrade,
  GradingStore,
  QuotaLimits,
  QuotaTake,
  UsageOutcome,
} from "./store.ts";

export interface HandlerConfig {
  model: string;
  /** null — функция не настроена (нет ключа OpenRouter или неверный env): 503. */
  configError: string | null;
  limits: QuotaLimits;
  /** Точные Origin (`https://x.github.io`) или `http://localhost:*` (любой порт). */
  allowedOrigins: string[];
  /** Сколько всего можно ждать модель, считая повторы (карточка T15: 12 с). */
  modelDeadlineMs: number;
  thresholds?: Thresholds;
}

/** Один вызов модели: messages + format → ответ OpenRouter; бросает OpenRouterError. */
export type ModelCall = (
  messages: Parameters<CompleteFn>[0],
  format: Parameters<CompleteFn>[1],
  timeoutMs: number,
) => Promise<CompletionResult>;

export interface HandlerDeps {
  config: HandlerConfig;
  auth: Authenticator;
  decks: DeckLookup;
  store: GradingStore;
  model: ModelCall;
  /** Монотонные миллисекунды (performance.now) — дедлайн и латентность. */
  now?: () => number;
  log?: (entry: Record<string, unknown>) => void;
}

/** Меньше этого на попытку не начинаем: всё равно не успеет. */
const MIN_ATTEMPT_MS = 1500;
/** HTTP-вызовов модели на запрос (повторы включены); резерв бюджета — на столько. */
export const MAX_MODEL_CALLS = 2;
const MAX_FEEDBACK_CHARS = 300;
const MAX_TOKEN_CHARS = 16 * 1024;

const ERROR_STATUS: Record<ErrorCode, number> = {
  invalid_json: 400,
  invalid_request: 400,
  unknown_field: 400,
  answer_too_long: 400,
  question_not_open: 400,
  unauthorized: 401,
  origin_not_allowed: 403,
  deck_not_found: 404,
  question_not_found: 404,
  method_not_allowed: 405,
  payload_too_large: 413,
  unsupported_media_type: 415,
  quota_exceeded: 429,
  request_limit: 429,
  budget_exceeded: 429,
  internal: 500,
  model_error: 502,
  grading_unavailable: 503,
  model_timeout: 504,
};

const ERROR_MESSAGE: Partial<Record<ErrorCode, string>> = {
  unauthorized: "нужен вход",
  origin_not_allowed: "origin не разрешён",
  deck_not_found: "колода или её версия не найдена",
  question_not_found: "вопрос не найден в колоде",
  question_not_open: "вопрос не типа open",
  method_not_allowed: "только POST",
  payload_too_large: `тело больше ${MAX_BODY_BYTES} байт`,
  unsupported_media_type: "нужен Content-Type: application/json",
  quota_exceeded: "дневной лимит проверок исчерпан",
  request_limit: "дневной лимит запросов исчерпан",
  budget_exceeded: "проверка временно недоступна",
  internal: "внутренняя ошибка",
  model_error: "модель недоступна",
  grading_unavailable: "проверка не настроена",
  model_timeout: "модель не ответила вовремя",
};

const QUOTA_CODE: Record<NonNullable<QuotaTake["reason"]>, ErrorCode> = {
  quota: "quota_exceeded",
  requests: "request_limit",
  budget: "budget_exceeded",
};

class HttpError extends Error {
  constructor(
    readonly code: ErrorCode,
    readonly extra: { field?: string; message?: string; resetAt?: string } = {},
  ) {
    super(code);
  }
}

// ---------------------------------------------------------------------------
// CORS

export function originAllowed(origin: string, allowed: string[]): boolean {
  for (const a of allowed) {
    if (a === origin) return true;
    if (a.endsWith(":*")) {
      const base = a.slice(0, -2);
      if (
        origin === base ||
        new RegExp(`^${escapeRe(base)}:\\d{1,5}$`).test(origin)
      ) {
        return true;
      }
    }
  }
  return false;
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function corsHeaders(origin: string | null): Record<string, string> {
  return origin === null ? {} : {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Expose-Headers": "Retry-After, X-Request-Id",
    Vary: "Origin",
  };
}

// ---------------------------------------------------------------------------
// Ответ модели → ответ клиенту

/** До двух предложений и MAX_FEEDBACK_CHARS символов, без обрыва посреди слова. */
export function tidyFeedback(text: string): string {
  const t = text.replace(/\s+/g, " ").trim();
  if (t === "") return "";
  const sentences = t.match(/[^.!?…]+(?:[.!?…]+|$)/g) ?? [t];
  let out = "";
  for (const s of sentences.slice(0, 2)) {
    const next = `${out} ${s.trim()}`.trim();
    if ([...next].length > MAX_FEEDBACK_CHARS) break;
    out = next;
  }
  return out;
}

/** Вердикт, балл и «что упущено» по разбору модели; одна функция для свежей оценки и кэша. */
export function buildResult(
  grade: CachedGrade,
  question: OpenQuestion,
  thresholds: Thresholds,
): Pick<
  GradeResponse,
  "verdict" | "score" | "points" | "missed" | "feedback" | "suggested_rating"
> {
  const scored = scoreGrade(
    {
      points: grade.points.map((p) => ({ ...p, evidence: "" })),
      contradiction: grade.contradiction,
      verdict: grade.model_verdict,
    },
    question.rubric,
    thresholds,
  );
  const status = new Map(grade.points.map((p) => [p.id, p.status]));
  const missed: MissedPoint[] = [];
  for (const r of question.rubric) {
    const s = status.get(r.id) ?? "miss";
    if (s !== "hit") {
      missed.push({ id: r.id, text: r.text, status: s, required: r.required });
    }
  }
  return {
    verdict: scored.verdict,
    score: Math.round(scored.score * 100) / 100,
    points: question.rubric.map((r) => ({
      id: r.id,
      status: status.get(r.id) ?? "miss",
    })),
    missed,
    // Модель иногда пишет «не указано X» при X = hit (T07, ADR-28): если
    // упущенного нет, её комментарий не показываем.
    feedback: missed.length === 0 ? "" : tidyFeedback(grade.feedback),
    suggested_rating: suggestedRating(scored.verdict),
  };
}

/** Кэшированный разбор годится, только если его пункты — ровно пункты рубрики. */
function cachedFits(c: unknown, question: OpenQuestion): c is CachedGrade {
  if (typeof c !== "object" || c === null) return false;
  const g = c as Record<string, unknown>;
  if (
    !Array.isArray(g.points) || typeof g.contradiction !== "boolean" ||
    typeof g.feedback !== "string" ||
    !["correct", "partial", "incorrect", "unsure"].includes(
      g.model_verdict as string,
    )
  ) {
    return false;
  }
  const ids = question.rubric.map((r) => r.id).sort().join("\n");
  const got = g.points.map((p) => p?.id).sort().join("\n");
  return ids === got &&
    g.points.every((p) => ["hit", "partial", "miss"].includes(p?.status));
}

export async function cacheKey(
  questionId: string,
  deckVersion: number,
  answer: string,
): Promise<string> {
  const data = new TextEncoder().encode(
    `${questionId}|${deckVersion}|${normalizeAnswer(answer)}`,
  );
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  return Array.from(hash, (b) => b.toString(16).padStart(2, "0")).join("");
}

// ---------------------------------------------------------------------------
// Тело запроса

async function readBody(req: Request): Promise<unknown> {
  const type = req.headers.get("content-type") ?? "";
  if (!/^application\/json\s*(;|$)/i.test(type)) {
    throw new HttpError("unsupported_media_type");
  }
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY_BYTES) throw new HttpError("payload_too_large");
  const chunks: Uint8Array[] = [];
  let size = 0;
  if (req.body) {
    const reader = req.body.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > MAX_BODY_BYTES) {
        await reader.cancel();
        throw new HttpError("payload_too_large");
      }
      chunks.push(value);
    }
  }
  const bytes = new Uint8Array(size);
  let at = 0;
  for (const c of chunks) {
    bytes.set(c, at);
    at += c.length;
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new HttpError("invalid_json", { message: "тело — не JSON" });
  }
}

function bearer(req: Request): string | null {
  const h = req.headers.get("authorization");
  const m = h?.match(/^Bearer ([A-Za-z0-9._~+/=-]+)$/);
  return m && m[1].length <= MAX_TOKEN_CHARS ? m[1] : null;
}

// ---------------------------------------------------------------------------

interface Ctx {
  rid: string;
  started: number;
  log: Record<string, unknown>;
}

export function createHandler(
  deps: HandlerDeps,
): (req: Request) => Promise<Response> {
  const now = deps.now ?? (() => performance.now());
  const log = deps.log ??
    ((e: Record<string, unknown>) => console.log(JSON.stringify(e)));
  const cfg = deps.config;
  const thresholds = cfg.thresholds ?? DEFAULT_THRESHOLDS;

  return async (req: Request): Promise<Response> => {
    const ctx: Ctx = {
      rid: crypto.randomUUID(),
      started: now(),
      log: {},
    };
    const rawOrigin = req.headers.get("origin");
    const origin =
      rawOrigin !== null && originAllowed(rawOrigin, cfg.allowedOrigins)
        ? rawOrigin
        : null;

    const finish = (status: number, body: unknown, headers = {}): Response => {
      log({
        fn: "grade-open-answer",
        rid: ctx.rid,
        status,
        ms: Math.round(now() - ctx.started),
        ...ctx.log,
      });
      return new Response(body === null ? null : JSON.stringify(body), {
        status,
        headers: {
          ...(body === null ? {} : { "Content-Type": "application/json" }),
          "X-Request-Id": ctx.rid,
          ...corsHeaders(origin),
          ...headers,
        },
      });
    };
    const fail = (e: HttpError): Response => {
      const body: ErrorBody = {
        error: {
          code: e.code,
          message: e.extra.message ?? ERROR_MESSAGE[e.code] ??
            "неверный запрос",
        },
      };
      if (e.extra.field) body.error.field = e.extra.field;
      const headers: Record<string, string> = {};
      if (e.extra.resetAt) {
        body.error.reset_at = e.extra.resetAt;
        const wait = Math.ceil(
          (Date.parse(e.extra.resetAt) - Date.now()) / 1000,
        );
        headers["Retry-After"] = String(Math.max(1, wait));
      }
      ctx.log.code = e.code;
      if (e.extra.field) ctx.log.field = e.extra.field;
      return finish(ERROR_STATUS[e.code], body, headers);
    };

    // Браузер с чужого Origin: отказ до любой работы. Без Origin (Android,
    // curl) CORS не участвует.
    if (rawOrigin !== null && origin === null) {
      return fail(new HttpError("origin_not_allowed"));
    }
    if (req.method === "OPTIONS") {
      if (origin === null) return fail(new HttpError("origin_not_allowed"));
      return finish(204, null, {
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
        "Access-Control-Max-Age": "600",
      });
    }

    try {
      return await handlePost(req, ctx, finish);
    } catch (e) {
      if (e instanceof HttpError) return fail(e);
      // Только тип и статус: в сообщениях могут быть фрагменты чужих ответов.
      ctx.log.error = e instanceof Error ? e.name : "unknown";
      if (e instanceof DeckInvalidError) ctx.log.error_detail = e.message;
      const status = (e as { status?: unknown })?.status;
      if (typeof status === "number") ctx.log.upstream_status = status;
      return fail(new HttpError("internal"));
    }
  };

  async function handlePost(
    req: Request,
    ctx: Ctx,
    finish: (status: number, body: unknown) => Response,
  ): Promise<Response> {
    if (req.method !== "POST") throw new HttpError("method_not_allowed");
    const token = bearer(req);
    if (token === null) throw new HttpError("unauthorized");

    const parsed = parseGradeRequest(await readBody(req));
    if (!parsed.ok) {
      throw new HttpError(parsed.code, {
        field: parsed.field,
        message: parsed.message,
      });
    }
    const input: GradeRequest = parsed.value;
    ctx.log.deck_id = input.deck_id;
    ctx.log.deck_version = input.deck_version;
    ctx.log.question_id = input.question_id;
    ctx.log.input_mode = input.input_mode;

    const user = await deps.auth.getUser(token);
    if (user === null) throw new HttpError("unauthorized");

    if (cfg.configError !== null) {
      ctx.log.config_error = cfg.configError;
      throw new HttpError("grading_unavailable");
    }

    const found = await deps.decks.lookup(
      token,
      input.deck_id,
      input.deck_version,
      input.question_id,
    );
    if (found.kind === "deck_not_found") throw new HttpError("deck_not_found");
    if (found.kind === "question_not_found") {
      throw new HttpError("question_not_found");
    }
    if (found.kind === "not_open") throw new HttpError("question_not_open");
    const { question, lang } = found;

    const usageBase = {
      user_id: user.id,
      task: "grade_open" as const,
      prompt_version: PROMPT_VERSION,
      deck_id: input.deck_id,
      deck_version: input.deck_version,
      question_id: input.question_id,
    };
    const take = async (modelCall: boolean): Promise<QuotaTake> => {
      const t = await deps.store.take(user.id, modelCall, cfg.limits);
      if (!t.allowed) {
        ctx.log.quota = t.reason;
        throw new HttpError(QUOTA_CODE[t.reason ?? "quota"], {
          resetAt: t.reset_at,
        });
      }
      return t;
    };
    const quotaFields = (t: QuotaTake) => ({
      remaining_quota: Math.max(0, cfg.limits.callLimit - t.model_calls),
      quota_reset_at: t.reset_at,
    });
    // Запись журнала и кэша не должна стоить пользователю оценки.
    const quietly = async (what: string, p: Promise<void>) => {
      try {
        await p;
      } catch (e) {
        ctx.log[`${what}_failed`] = (e as { status?: number })?.status ?? true;
      }
    };

    // §4.2, п. 1: пустой или короткий ответ — incorrect без модели и кэша.
    // Ключ кэша, проверка длины и текст для модели — от одной очищенной строки.
    const answer = sanitizeAnswer(input.answer_text);
    if (isTooShort(answer)) {
      const t = await take(false);
      ctx.log.outcome = "too_short";
      const body: GradeResponse = {
        verdict: "incorrect",
        score: 0,
        points: question.rubric.map((r) => ({ id: r.id, status: "miss" })),
        missed: question.rubric.map((r) => ({
          id: r.id,
          text: r.text,
          status: "miss",
          required: r.required,
        })),
        feedback: "",
        suggested_rating: 1,
        source: "rule",
        cached: false,
        ...quotaFields(t),
      };
      return finish(200, body);
    }

    // §4.2, п. 2: кэш. Попадание не тратит лимит вызовов модели (только
    // счётчик запросов) и не зовёт модель (AC5.3).
    const key = await cacheKey(
      input.question_id,
      input.deck_version,
      answer,
    );
    const hit = await deps.store.getCache(key, PROMPT_VERSION);
    if (hit !== null && cachedFits(hit.result, question)) {
      const t = await take(false);
      await quietly(
        "usage",
        deps.store.recordUsage({
          ...usageBase,
          model: hit.model,
          outcome: "cache_hit",
          cached: true,
          attempts: 0,
          tokens_in: 0,
          tokens_out: 0,
          cost_usd: 0,
          cost_estimated: false,
          latency_ms: 0,
        }),
      );
      const result = buildResult(hit.result, question, thresholds);
      ctx.log.outcome = "cache_hit";
      ctx.log.verdict = result.verdict;
      const body: GradeResponse = {
        ...result,
        source: "llm",
        cached: true,
        ...quotaFields(t),
      };
      return finish(200, body);
    }

    // §4.2, п. 3: лимит пользователя и глобальный бюджет, атомарно в БД.
    const t = await take(true);

    // §4.2, п. 4–6: модель (общий код T07), дедлайн на все попытки. Всего не
    // больше MAX_MODEL_CALLS HTTP-вызовов (повтор при невалидном JSON и повтор
    // при сбое сети делят их): на это рассчитан резерв бюджета.
    const deadline = now() + cfg.modelDeadlineMs;
    const calls: CompletionResult[] = [];
    let failedCalls = 0;
    const complete: CompleteFn = async (messages, format) => {
      for (;;) {
        const left = deadline - now();
        if (
          left < MIN_ATTEMPT_MS || calls.length + failedCalls >= MAX_MODEL_CALLS
        ) {
          throw new OpenRouterError("timeout", 0, true);
        }
        try {
          const r = await deps.model(messages, format, left);
          calls.push(r);
          return r.content;
        } catch (e) {
          // Ответа нет, но запрос мог дойти до провайдера и стоить денег.
          failedCalls++;
          if (
            !(e instanceof OpenRouterError) || !e.retryable ||
            calls.length + failedCalls >= MAX_MODEL_CALLS
          ) {
            throw e;
          }
          ctx.log.retried = e.status;
        }
      }
    };
    const modelStarted = now();
    // Фактическая стоимость: известная usage.cost плюс верхняя оценка на
    // КАЖДУЮ попытку без известной стоимости (сбой или кривой usage).
    const spent = () => {
      let usd = 0;
      let estimated = failedCalls > 0;
      for (const c of calls) {
        const cost = c.usage.cost;
        if (typeof cost === "number" && Number.isFinite(cost) && cost >= 0) {
          usd += cost;
        } else {
          estimated = true;
          usd += cfg.limits.unknownCostUsd;
        }
      }
      usd += failedCalls * cfg.limits.unknownCostUsd;
      return { usd: Math.round(usd * 1e8) / 1e8, estimated };
    };
    const tokens = (n: unknown) =>
      typeof n === "number" && Number.isFinite(n) && n >= 0
        ? Math.min(Math.round(n), 10_000_000)
        : 0;
    const usage = (outcome: UsageOutcome) => {
      const cost = spent();
      return {
        ...usageBase,
        model: cfg.model,
        outcome,
        cached: false,
        attempts: calls.length + failedCalls,
        tokens_in: calls.reduce((s, c) => s + tokens(c.usage.prompt_tokens), 0),
        tokens_out: calls.reduce(
          (s, c) => s + tokens(c.usage.completion_tokens),
          0,
        ),
        cost_usd: cost.usd,
        cost_estimated: cost.estimated,
        latency_ms: Math.min(Math.round(now() - modelStarted), 600_000),
      };
    };
    // Резерв бюджета заменяется фактической стоимостью; журнал — аудит.
    const account = async (outcome: UsageOutcome) => {
      const u = usage(outcome);
      ctx.log.cost_usd = u.cost_usd;
      await Promise.all([
        quietly(
          "settle",
          deps.store.settle(t.day, cfg.limits.reserveUsd, u.cost_usd),
        ),
        quietly("usage", deps.store.recordUsage(u)),
      ]);
    };

    let graded: GradeResult | null = null;
    try {
      graded = await gradeOpenAnswer(
        {
          question,
          answer,
          inputMode: input.input_mode,
          lang,
          thresholds,
        },
        complete,
      );
    } catch (e) {
      if (e instanceof OpenRouterError) ctx.log.model_status = e.status;
      if (calls.length === 0) {
        // Модель не ответила ни разу: лимит возвращается (сбой не по вине
        // пользователя), клиент переходит на самооценку по коду ошибки.
        const timeout = e instanceof OpenRouterError && e.status === 0 &&
          e.message === "timeout";
        const outcome = timeout ? "model_timeout" : "model_error";
        ctx.log.outcome = outcome;
        await quietly("refund", deps.store.refund(user.id, t.day));
        await account(outcome);
        throw new HttpError(outcome);
      }
      // Первый ответ не разобран, а повтор не удался: как невалидный вывод.
    }

    ctx.log.attempts = calls.length + failedCalls;
    ctx.log.model_ms = Math.round(now() - modelStarted);
    if (graded === null || graded.rule === "invalid_output") {
      // §4.2, п. 4: невалидный JSON и после повтора — unsure, не кэшируется.
      // Лимит НЕ возвращается: модель ответила, деньги потрачены, а сломать
      // JSON может сам ввод пользователя (иначе лимит обходился бы).
      ctx.log.outcome = "invalid_output";
      if (graded) ctx.log.parse_errors = graded.parse_errors;
      await account("invalid_output");
      const body: GradeResponse = {
        verdict: "unsure",
        score: 0,
        points: [],
        missed: [],
        feedback: "",
        suggested_rating: null,
        source: "llm",
        cached: false,
        ...quotaFields(t),
      };
      return finish(200, body);
    }

    // Сохраняется разбор модели (без evidence): вердикт пересчитывается при
    // каждом попадании в кэш по текущим порогам.
    const cached: CachedGrade = {
      points: graded.points,
      contradiction: graded.contradiction ?? false,
      model_verdict: graded.model_verdict ?? "unsure",
      feedback: graded.feedback,
    };
    await Promise.all([
      account("graded"),
      quietly(
        "cache",
        deps.store.putCache({
          key,
          deck_id: input.deck_id,
          deck_version: input.deck_version,
          question_id: input.question_id,
          prompt_version: PROMPT_VERSION,
          model: cfg.model,
          result: cached,
        }),
      ),
    ]);
    const result = buildResult(cached, question, thresholds);
    ctx.log.outcome = "graded";
    ctx.log.verdict = result.verdict;
    const body: GradeResponse = {
      ...result,
      source: "llm",
      cached: false,
      ...quotaFields(t),
    };
    return finish(200, body);
  }
}
