// Рубрика и эталон — из серверной копии колоды (ТЗ §5.2, §7.1, ADR-7, ADR-31).
//
// 1. Доступ: строка `decks` читается с JWT пользователя, поэтому действует та
//    же RLS, что у клиента (0002_decks.sql): чужая private-колода для функции
//    «не существует». Проверка идёт на каждый запрос, даже при попадании в
//    кэш файла. Запрошенная версия не может быть новее текущей.
// 2. Файл `decks/<id>/v<version>.json` из Storage скачивается ключом service
//    role и кэшируется в памяти изолята по `id@version` (файлы версий не
//    меняются: импорт только повышает версию). Хранится только карта вопросов.

import type { OpenQuestion, RubricPoint } from "../_shared/grading.ts";

export type QuestionLookup =
  | { kind: "ok"; question: OpenQuestion; lang: string }
  | { kind: "deck_not_found" }
  | { kind: "question_not_found" }
  | { kind: "not_open" };

export interface DeckLookup {
  lookup(
    userToken: string,
    deckId: string,
    deckVersion: number,
    questionId: string,
  ): Promise<QuestionLookup>;
}

/** Колода в Storage не соответствует контракту (импорт обошёл валидатор): 500. */
export class DeckInvalidError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DeckInvalidError";
  }
}

/** Сбой Supabase (сеть, 5xx, неожиданный ответ): 500. Без тела ответа и ключей. */
export class UpstreamError extends Error {
  constructor(what: string, readonly status: number) {
    super(`${what}: HTTP ${status}`);
    this.name = "UpstreamError";
  }
}

interface LoadedDeck {
  lang: string;
  /** Сырые вопросы по id; разбор `open` — при обращении. */
  questions: Map<string, Record<string, unknown>>;
}

export interface DeckSourceOptions {
  supabaseUrl: string;
  /** Публичный ключ (anon / publishable) для запроса с JWT пользователя. */
  anonKey: string;
  serviceKey: string;
  fetchFn?: typeof fetch;
  /** Сколько колод держать в памяти. */
  maxEntries?: number;
  /** Лимит bucket `decks` (0002_decks.sql). */
  maxDeckBytes?: number;
}

export function serviceHeaders(serviceKey: string): Record<string, string> {
  // Новые ключи `sb_secret_…` не JWT: их шлют только в apikey.
  return serviceKey.startsWith("sb_")
    ? { apikey: serviceKey }
    : { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` };
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

/** Строгий разбор `open`-вопроса колоды (deck.schema.json, §7.1). */
export function parseOpenQuestion(q: Record<string, unknown>): OpenQuestion {
  const p = q.payload;
  if (
    typeof q.id !== "string" || typeof q.prompt !== "string" ||
    q.prompt.trim() === "" || !isObject(p) ||
    typeof p.reference_answer !== "string" ||
    p.reference_answer.trim() === "" || !Array.isArray(p.rubric) ||
    p.rubric.length < 2 || p.rubric.length > 5
  ) {
    throw new DeckInvalidError("open: prompt, reference_answer или rubric");
  }
  const ids = new Set<string>();
  const rubric: RubricPoint[] = p.rubric.map((r: unknown) => {
    if (
      !isObject(r) || typeof r.id !== "string" ||
      !/^[A-Za-z0-9_-]+$/.test(r.id) || ids.has(r.id) ||
      typeof r.text !== "string" || r.text.trim() === "" ||
      !Number.isInteger(r.weight) || (r.weight as number) < 1 ||
      (r.weight as number) > 3 || typeof r.required !== "boolean"
    ) {
      throw new DeckInvalidError("open: пункт рубрики");
    }
    ids.add(r.id);
    return {
      id: r.id,
      text: r.text,
      weight: r.weight as number,
      required: r.required,
    };
  });
  if (!rubric.some((r) => r.required)) {
    throw new DeckInvalidError("open: нет required-пункта");
  }
  return {
    id: q.id,
    prompt: q.prompt,
    reference_answer: p.reference_answer,
    rubric,
  };
}

export class DeckSource implements DeckLookup {
  readonly #url: string;
  readonly #anonKey: string;
  readonly #serviceKey: string;
  readonly #fetch: typeof fetch;
  readonly #maxEntries: number;
  readonly #maxDeckBytes: number;
  /** Промис, чтобы параллельные запросы к одной колоде качали её один раз. */
  readonly #cache = new Map<string, Promise<LoadedDeck | null>>();

  constructor(o: DeckSourceOptions) {
    this.#url = o.supabaseUrl.replace(/\/+$/, "");
    this.#anonKey = o.anonKey;
    this.#serviceKey = o.serviceKey;
    this.#fetch = o.fetchFn ?? fetch;
    this.#maxEntries = o.maxEntries ?? 16;
    this.#maxDeckBytes = o.maxDeckBytes ?? 10 * 1024 * 1024;
  }

  async lookup(
    userToken: string,
    deckId: string,
    deckVersion: number,
    questionId: string,
  ): Promise<QuestionLookup> {
    const current = await this.#visibleVersion(userToken, deckId);
    if (current === null || deckVersion > current) {
      return { kind: "deck_not_found" };
    }
    const deck = await this.#load(deckId, deckVersion);
    if (deck === null) return { kind: "deck_not_found" };
    const raw = deck.questions.get(questionId);
    if (raw === undefined) return { kind: "question_not_found" };
    if (raw.type !== "open") return { kind: "not_open" };
    return { kind: "ok", question: parseOpenQuestion(raw), lang: deck.lang };
  }

  /** Текущая версия колоды, если пользователь её видит (RLS), иначе null. */
  async #visibleVersion(token: string, deckId: string): Promise<number | null> {
    const url = `${this.#url}/rest/v1/decks?select=version&id=eq.${
      encodeURIComponent(deckId)
    }`;
    const res = await this.#fetch(url, {
      headers: { apikey: this.#anonKey, Authorization: `Bearer ${token}` },
      redirect: "error",
    });
    if (!res.ok) {
      await res.body?.cancel();
      throw new UpstreamError("decks", res.status);
    }
    const rows = await res.json();
    if (!Array.isArray(rows) || rows.length === 0) return null;
    const v = rows[0]?.version;
    if (!Number.isInteger(v)) throw new UpstreamError("decks", 200);
    return v;
  }

  #load(deckId: string, version: number): Promise<LoadedDeck | null> {
    const key = `${deckId}@${version}`;
    const hit = this.#cache.get(key);
    if (hit) {
      // Вперёд в порядке вставки: Map как LRU.
      this.#cache.delete(key);
      this.#cache.set(key, hit);
      return hit;
    }
    const p = this.#download(deckId, version);
    this.#cache.set(key, p);
    // Отсутствие файла и ошибки не кэшируются.
    const forget = () => {
      if (this.#cache.get(key) === p) this.#cache.delete(key);
    };
    p.then((d) => d === null && forget(), forget);
    while (this.#cache.size > this.#maxEntries) {
      this.#cache.delete(this.#cache.keys().next().value!);
    }
    return p;
  }

  async #download(deckId: string, version: number): Promise<LoadedDeck | null> {
    const path = `${encodeURIComponent(deckId)}/v${version}.json`;
    const res = await this.#fetch(
      `${this.#url}/storage/v1/object/decks/${path}`,
      { headers: serviceHeaders(this.#serviceKey), redirect: "error" },
    );
    if (res.status === 404 || res.status === 400) {
      // Storage отвечает 400 { statusCode: "404" } на отсутствующий объект.
      const body = await res.text();
      if (res.status === 404 || /not.?found/i.test(body)) return null;
      throw new UpstreamError("storage", res.status);
    }
    if (!res.ok) {
      await res.body?.cancel();
      throw new UpstreamError("storage", res.status);
    }
    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.length > this.#maxDeckBytes) {
      throw new DeckInvalidError("файл колоды больше лимита");
    }
    let deck: unknown;
    try {
      deck = JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(bytes),
      );
    } catch {
      throw new DeckInvalidError("файл колоды — не JSON");
    }
    if (
      !isObject(deck) || deck.id !== deckId || deck.version !== version ||
      typeof deck.lang !== "string" || !Array.isArray(deck.items)
    ) {
      throw new DeckInvalidError("id, version, lang или items колоды");
    }
    const questions = new Map<string, Record<string, unknown>>();
    for (const item of deck.items) {
      if (!isObject(item) || !Array.isArray(item.questions)) {
        throw new DeckInvalidError("знание без questions");
      }
      for (const q of item.questions) {
        if (!isObject(q) || typeof q.id !== "string") {
          throw new DeckInvalidError("вопрос без id");
        }
        questions.set(q.id, q);
      }
    }
    return { lang: deck.lang, questions };
  }
}
