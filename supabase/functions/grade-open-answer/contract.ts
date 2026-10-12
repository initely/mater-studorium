// Контракт Edge Function `grade-open-answer` (ТЗ §5.2, M5, ADR-31).
// Источник истины для клиента (T16): README.md рядом повторяет его с
// примерами. Меняется только вместе с README и тестами.

import {
  type InputMode,
  MAX_ANSWER_CHARS,
  type PointStatus,
  type Verdict,
} from "../_shared/grading.ts";

export { MAX_ANSWER_CHARS };

/** Тело запроса больше — 413. 2000 символов ответа в худшем случае (\uXXXX) ≈ 24 КиБ. */
export const MAX_BODY_BYTES = 32 * 1024;

/** Формат id колоды, знания и вопроса (deck.schema.json). */
const ID_RE = /^[a-z0-9]+([._-][a-z0-9]+)*$/;

/** Запрос клиента. Рубрику и эталон сервер берёт из своей копии колоды. */
export interface GradeRequest {
  deck_id: string;
  deck_version: number;
  question_id: string;
  answer_text: string;
  input_mode: InputMode;
}

export interface GradedPoint {
  id: string;
  status: PointStatus;
}

/** Упущенный или раскрытый частично пункт: текст берётся из рубрики колоды. */
export interface MissedPoint {
  id: string;
  text: string;
  status: "miss" | "partial";
  required: boolean;
}

/** Ответ 200. */
export interface GradeResponse {
  /** `unsure` — модель не уверена или её ответ не разобран: клиент переходит на самооценку. */
  verdict: Verdict;
  /** 0…1, два знака; при `unsure` из-за невалидного ответа модели — 0. */
  score: number;
  /** Статусы пунктов в порядке рубрики; пусто, если оценки по пунктам нет. */
  points: GradedPoint[];
  /** Что упущено: собрано сервером из текстов пунктов miss/partial (не моделью). */
  missed: MissedPoint[];
  /** Комментарий модели (≤ 2 предложений, ≤ 300 символов) или ""; пусто, если упущенного нет. */
  feedback: string;
  /** Предложенная оценка FSRS: 3 Good, 2 Hard, 1 Again, null — без подсказки (§4.1). */
  suggested_rating: 1 | 2 | 3 | null;
  /** `llm` — оценила модель (сейчас или из кэша); `rule` — короткий ответ, модель не вызывалась. */
  source: "llm" | "rule";
  cached: boolean;
  /** Сколько вызовов модели осталось на текущие UTC-сутки. */
  remaining_quota: number;
  /** Когда обнулится лимит (ISO 8601, UTC-полночь). */
  quota_reset_at: string;
}

export type ErrorCode =
  | "invalid_json" // 400
  | "invalid_request" // 400: поле отсутствует, не того типа, вне границ (`field`)
  | "unknown_field" // 400: лишнее поле (например, `rubric`) (`field`)
  | "answer_too_long" // 400
  | "question_not_open" // 400: вопрос не типа `open`
  | "unauthorized" // 401: нет или неверный JWT пользователя
  | "origin_not_allowed" // 403: Origin браузера не в списке
  | "deck_not_found" // 404: колоды нет, она не видна пользователю или нет такой версии
  | "question_not_found" // 404
  | "method_not_allowed" // 405
  | "payload_too_large" // 413
  | "unsupported_media_type" // 415
  | "quota_exceeded" // 429: дневной лимит вызовов модели (`reset_at`)
  | "request_limit" // 429: дневной лимит запросов (`reset_at`)
  | "budget_exceeded" // 429: исчерпан глобальный дневной бюджет (`reset_at`)
  | "internal" // 500
  | "model_error" // 502: OpenRouter или провайдер вернули ошибку
  | "grading_unavailable" // 503: функция не настроена (нет ключа и т. п.)
  | "model_timeout"; // 504

export interface ErrorBody {
  error: {
    code: ErrorCode;
    message: string;
    field?: string;
    reset_at?: string;
  };
}

export type ParseResult =
  | { ok: true; value: GradeRequest }
  | { ok: false; code: ErrorCode; field?: string; message: string };

const FIELDS = [
  "deck_id",
  "deck_version",
  "question_id",
  "answer_text",
  "input_mode",
] as const;

function bad(field: string, message: string): ParseResult {
  return { ok: false, code: "invalid_request", field, message };
}

function isId(v: unknown, max: number): v is string {
  return typeof v === "string" && v.length <= max && ID_RE.test(v);
}

/**
 * Строгая проверка тела. Лишние поля — ошибка: клиент не может прислать
 * свою рубрику, эталон, язык или модель, даже если сервер их и так бы
 * проигнорировал.
 */
export function parseGradeRequest(data: unknown): ParseResult {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    return {
      ok: false,
      code: "invalid_json",
      message: "ожидается JSON-объект",
    };
  }
  const obj = data as Record<string, unknown>;
  for (const k of Object.keys(obj)) {
    if (!(FIELDS as readonly string[]).includes(k)) {
      return {
        ok: false,
        code: "unknown_field",
        field: k.slice(0, 64),
        message: "лишнее поле",
      };
    }
  }
  if (!isId(obj.deck_id, 64)) return bad("deck_id", "неверный id колоды");
  const v = obj.deck_version;
  if (typeof v !== "number" || !Number.isInteger(v) || v < 1 || v > 1_000_000) {
    return bad("deck_version", "версия — целое 1…1000000");
  }
  if (!isId(obj.question_id, 128)) {
    return bad("question_id", "неверный id вопроса");
  }
  if (typeof obj.answer_text !== "string") {
    return bad("answer_text", "ответ — строка");
  }
  if (obj.answer_text.length > MAX_ANSWER_CHARS) {
    return {
      ok: false,
      code: "answer_too_long",
      field: "answer_text",
      message: `ответ длиннее ${MAX_ANSWER_CHARS} символов`,
    };
  }
  if (obj.input_mode !== "text" && obj.input_mode !== "voice") {
    return bad("input_mode", "input_mode — text или voice");
  }
  return {
    ok: true,
    value: {
      deck_id: obj.deck_id,
      deck_version: v,
      question_id: obj.question_id,
      answer_text: obj.answer_text,
      input_mode: obj.input_mode,
    },
  };
}
