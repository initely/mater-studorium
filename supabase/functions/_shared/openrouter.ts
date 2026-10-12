// Минимальный клиент OpenRouter chat completions (ТЗ §5.2, ADR-9).
// Только fetch и AbortController: работает и в Edge Function, и в eval.
// Ключ передаёт вызывающий; в ошибки и логи он не попадает.

import type { ChatMessage } from "./grading.ts";

export const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

export interface CompletionRequest {
  apiKey: string;
  model: string;
  messages: ChatMessage[];
  responseFormat?: unknown;
  /** Не передаётся, если модель его не поддерживает (иначе require_parameters отсеет всех провайдеров). */
  temperature?: number;
  seed?: number;
  maxTokens?: number;
  /** Например `{ enabled: false }` или `{ effort: "low" }`. */
  reasoning?: Record<string, unknown>;
  timeoutMs?: number;
  title?: string;
  fetchFn?: typeof fetch;
}

export interface CompletionUsage {
  prompt_tokens: number;
  completion_tokens: number;
  reasoning_tokens: number;
  /** Стоимость в USD по данным OpenRouter (usage.cost), null если не пришла. */
  cost: number | null;
}

export interface CompletionResult {
  content: string;
  usage: CompletionUsage;
  latencyMs: number;
  id?: string;
  provider?: string;
  model?: string;
}

export class OpenRouterError extends Error {
  constructor(
    message: string,
    /** HTTP-статус; 0 — сеть или таймаут. */
    readonly status: number,
    /** Есть смысл повторить: таймаут, 429, 5xx. */
    readonly retryable: boolean,
  ) {
    super(message);
    this.name = "OpenRouterError";
  }
}

export async function chatCompletion(
  req: CompletionRequest,
): Promise<CompletionResult> {
  const body: Record<string, unknown> = {
    model: req.model,
    messages: req.messages,
    max_tokens: req.maxTokens ?? 800,
    // Провайдер обязан поддерживать все переданные параметры (в т.ч. response_format).
    provider: { require_parameters: true },
    usage: { include: true },
  };
  if (req.responseFormat !== undefined) {
    body.response_format = req.responseFormat;
  }
  if (req.temperature !== undefined) body.temperature = req.temperature;
  if (req.seed !== undefined) body.seed = req.seed;
  if (req.reasoning !== undefined) body.reasoning = req.reasoning;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), req.timeoutMs ?? 15_000);
  const started = performance.now();
  let res: Response;
  try {
    res = await (req.fetchFn ?? fetch)(OPENROUTER_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${req.apiKey}`,
        "Content-Type": "application/json",
        "X-Title": req.title ?? "Mater Studorium",
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (e) {
    clearTimeout(timer);
    const aborted = e instanceof DOMException && e.name === "AbortError";
    throw new OpenRouterError(aborted ? "timeout" : "network_error", 0, true);
  }
  let json: Record<string, unknown>;
  try {
    json = await res.json();
  } catch {
    clearTimeout(timer);
    throw new OpenRouterError(
      `bad_response_body (HTTP ${res.status})`,
      res.status,
      res.status === 429 || res.status >= 500,
    );
  }
  clearTimeout(timer);
  const latencyMs = performance.now() - started;

  // OpenRouter может вернуть 200 с { error } (ошибка провайдера).
  const error = json.error as { message?: string; code?: number } | undefined;
  if (!res.ok || error) {
    const status = res.ok ? (error?.code ?? 502) : res.status;
    throw new OpenRouterError(
      `HTTP ${status}: ${String(error?.message ?? "").slice(0, 200)}`,
      status,
      status === 429 || status >= 500,
    );
  }

  const choices = json.choices as
    | { message?: { content?: unknown } }[]
    | undefined;
  const content = choices?.[0]?.message?.content;
  const usage = (json.usage ?? {}) as Record<string, unknown>;
  const details = (usage.completion_tokens_details ?? {}) as Record<
    string,
    unknown
  >;
  return {
    content: typeof content === "string" ? content : "",
    usage: {
      prompt_tokens: Number(usage.prompt_tokens ?? 0),
      completion_tokens: Number(usage.completion_tokens ?? 0),
      reasoning_tokens: Number(details.reasoning_tokens ?? 0),
      cost: typeof usage.cost === "number" ? usage.cost : null,
    },
    latencyMs,
    id: typeof json.id === "string" ? json.id : undefined,
    provider: typeof json.provider === "string" ? json.provider : undefined,
    model: typeof json.model === "string" ? json.model : undefined,
  };
}
