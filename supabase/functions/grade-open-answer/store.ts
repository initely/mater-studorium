// Доступ функции к Supabase через REST (без supabase-js): проверка JWT
// пользователя в Auth и таблицы 0004_grading.sql с ключом service role.
// Ошибки — UpstreamError со статусом, без тела ответа и ключей.

import { serviceHeaders, UpstreamError } from "./deck_source.ts";
import type { PointStatus, Verdict } from "../_shared/grading.ts";

export interface AuthUser {
  id: string;
}

export interface Authenticator {
  /** Пользователь по JWT или null, если токен неверный, просрочен или не пользователя. */
  getUser(token: string): Promise<AuthUser | null>;
}

/** Что лежит в grading_cache.result: разбор модели, без текста ответа и evidence. */
export interface CachedGrade {
  points: { id: string; status: PointStatus }[];
  contradiction: boolean;
  model_verdict: Verdict;
  feedback: string;
}

export interface CacheRow {
  key: string;
  deck_id: string;
  deck_version: number;
  question_id: string;
  prompt_version: string;
  model: string;
  result: CachedGrade;
}

export interface QuotaTake {
  allowed: boolean;
  reason: "budget" | "requests" | "quota" | null;
  model_calls: number;
  requests: number;
  /** YYYY-MM-DD, UTC-сутки списания (для возврата). */
  day: string;
  reset_at: string;
}

export interface QuotaLimits {
  callLimit: number;
  requestLimit: number;
  budgetUsd: number;
  unknownCostUsd: number;
}

export type UsageOutcome =
  | "graded"
  | "cache_hit"
  | "invalid_output"
  | "model_error"
  | "model_timeout";

export interface UsageRow {
  user_id: string;
  task: "grade_open";
  model: string;
  prompt_version: string;
  deck_id: string;
  deck_version: number;
  question_id: string;
  outcome: UsageOutcome;
  cached: boolean;
  attempts: number;
  tokens_in: number;
  tokens_out: number;
  cost_usd: number | null;
  latency_ms: number | null;
}

export interface GradingStore {
  getCache(key: string, promptVersion: string): Promise<CacheRow | null>;
  putCache(row: CacheRow): Promise<void>;
  take(userId: string, modelCall: boolean, l: QuotaLimits): Promise<QuotaTake>;
  refund(userId: string, day: string): Promise<void>;
  recordUsage(row: UsageRow): Promise<void>;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface SupabaseOptions {
  supabaseUrl: string;
  anonKey: string;
  serviceKey: string;
  fetchFn?: typeof fetch;
}

export class SupabaseAuth implements Authenticator {
  readonly #url: string;
  readonly #anonKey: string;
  readonly #fetch: typeof fetch;

  constructor(o: SupabaseOptions) {
    this.#url = o.supabaseUrl.replace(/\/+$/, "");
    this.#anonKey = o.anonKey;
    this.#fetch = o.fetchFn ?? fetch;
  }

  async getUser(token: string): Promise<AuthUser | null> {
    // Auth проверяет подпись, срок и что сессия не отозвана; ключ anon (не
    // пользователь) получает 401/403.
    const res = await this.#fetch(`${this.#url}/auth/v1/user`, {
      headers: { apikey: this.#anonKey, Authorization: `Bearer ${token}` },
      redirect: "error",
    });
    if (res.status === 401 || res.status === 403) {
      await res.body?.cancel();
      return null;
    }
    if (!res.ok) {
      await res.body?.cancel();
      throw new UpstreamError("auth", res.status);
    }
    const user = await res.json();
    if (
      typeof user?.id !== "string" || !UUID_RE.test(user.id) ||
      user.role !== "authenticated"
    ) {
      return null;
    }
    return { id: user.id };
  }
}

export class SupabaseGradingStore implements GradingStore {
  readonly #url: string;
  readonly #headers: Record<string, string>;
  readonly #fetch: typeof fetch;

  constructor(o: SupabaseOptions) {
    this.#url = o.supabaseUrl.replace(/\/+$/, "");
    this.#headers = serviceHeaders(o.serviceKey);
    this.#fetch = o.fetchFn ?? fetch;
  }

  async #call(
    what: string,
    path: string,
    init: { method?: string; body?: unknown; prefer?: string } = {},
  ): Promise<unknown> {
    const headers: Record<string, string> = { ...this.#headers };
    if (init.body !== undefined) headers["Content-Type"] = "application/json";
    if (init.prefer) headers.Prefer = init.prefer;
    const res = await this.#fetch(`${this.#url}${path}`, {
      method: init.method ?? "GET",
      headers,
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
      redirect: "error",
    });
    if (!res.ok) {
      await res.body?.cancel();
      throw new UpstreamError(what, res.status);
    }
    const text = await res.text();
    return text === "" ? null : JSON.parse(text);
  }

  async getCache(key: string, promptVersion: string): Promise<CacheRow | null> {
    const rows = await this.#call(
      "grading_cache",
      `/rest/v1/grading_cache?select=*&key=eq.${encodeURIComponent(key)}` +
        `&prompt_version=eq.${encodeURIComponent(promptVersion)}`,
    );
    return Array.isArray(rows) && rows.length > 0 ? rows[0] as CacheRow : null;
  }

  async putCache(row: CacheRow): Promise<void> {
    // Новый разбор (например, после смены промпта) заменяет старую строку.
    await this.#call(
      "grading_cache",
      "/rest/v1/grading_cache?on_conflict=key",
      {
        method: "POST",
        body: row,
        prefer: "resolution=merge-duplicates,return=minimal",
      },
    );
  }

  async take(
    userId: string,
    modelCall: boolean,
    l: QuotaLimits,
  ): Promise<QuotaTake> {
    const rows = await this.#call("quota", "/rest/v1/rpc/grading_quota_take", {
      method: "POST",
      body: {
        p_user_id: userId,
        p_model_call: modelCall,
        p_call_limit: l.callLimit,
        p_request_limit: l.requestLimit,
        p_budget_usd: l.budgetUsd,
        p_unknown_cost_usd: l.unknownCostUsd,
      },
    });
    const r = Array.isArray(rows) ? rows[0] : null;
    if (
      typeof r?.allowed !== "boolean" || typeof r.model_calls !== "number" ||
      typeof r.day !== "string" || typeof r.reset_at !== "string"
    ) {
      throw new UpstreamError("quota", 200);
    }
    return {
      allowed: r.allowed,
      reason: r.reason ?? null,
      model_calls: r.model_calls,
      requests: r.requests,
      day: r.day,
      reset_at: new Date(r.reset_at).toISOString(),
    };
  }

  async refund(userId: string, day: string): Promise<void> {
    await this.#call("quota", "/rest/v1/rpc/grading_quota_refund", {
      method: "POST",
      body: { p_user_id: userId, p_day: day },
    });
  }

  async recordUsage(row: UsageRow): Promise<void> {
    await this.#call("llm_usage", "/rest/v1/llm_usage", {
      method: "POST",
      body: row,
      prefer: "return=minimal",
    });
  }
}
