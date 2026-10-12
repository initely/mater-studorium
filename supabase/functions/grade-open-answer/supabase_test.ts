// DeckSource и REST-адаптеры Supabase на фейковом fetch: какие запросы
// уходят, с какими ключами, и как разбираются ответы.
import {
  assert,
  assertEquals,
  assertFalse,
  assertRejects,
} from "jsr:@std/assert@1";
import {
  DeckInvalidError,
  DeckSource,
  parseOpenQuestion,
  UpstreamError,
} from "./deck_source.ts";
import { SupabaseAuth, SupabaseGradingStore } from "./store.ts";

const URL_ = "http://kong:8000";
const ANON = "anon-public-key";
const SERVICE = "service-role-jwt";
const USER_TOKEN = "user.jwt";

interface Seen {
  url: string;
  headers: Headers;
  method: string;
  body?: string;
  redirect?: RequestRedirect;
}

function fakeFetch(
  route: (url: string, init: RequestInit) => Response,
  seen: Seen[] = [],
) {
  return ((url: string, init: RequestInit = {}) => {
    seen.push({
      url,
      headers: new Headers(init.headers),
      method: init.method ?? "GET",
      body: init.body as string | undefined,
      redirect: init.redirect,
    });
    return Promise.resolve(route(url, init));
  }) as unknown as typeof fetch;
}

const OPEN = {
  id: "d.i.q2",
  type: "open",
  prompt: "Вопрос?",
  payload: {
    reference_answer: "Эталон.",
    rubric: [
      { id: "p1", text: "Пункт 1", weight: 2, required: true },
      { id: "p2", text: "Пункт 2", weight: 1, required: false },
    ],
  },
};

function deckJson(version = 2, extra: Record<string, unknown> = {}) {
  return JSON.stringify({
    schema_version: 1,
    id: "d",
    version,
    lang: "ru",
    items: [{
      id: "d.i",
      questions: [
        { id: "d.i.q1", type: "flip", prompt: "?", payload: { back: "!" } },
        OPEN,
      ],
    }],
    ...extra,
  });
}

function deckRoutes(o: { visible?: number | null; file?: string | null } = {}) {
  const visible = o.visible === undefined ? 2 : o.visible;
  return (url: string) => {
    if (url.includes("/rest/v1/decks")) {
      return Response.json(visible === null ? [] : [{ version: visible }]);
    }
    if (url.includes("/storage/v1/object/decks/")) {
      const file = o.file === undefined ? deckJson() : o.file;
      return file === null
        ? Response.json({ statusCode: "404", error: "not_found" }, {
          status: 400,
        })
        : new Response(file);
    }
    return new Response("?", { status: 500 });
  };
}

Deno.test("DeckSource: доступ с JWT пользователя, файл — ключом service role", async () => {
  const seen: Seen[] = [];
  const src = new DeckSource({
    supabaseUrl: URL_ + "/",
    anonKey: ANON,
    serviceKey: SERVICE,
    fetchFn: fakeFetch(deckRoutes(), seen),
  });
  const r = await src.lookup(USER_TOKEN, "d", 2, "d.i.q2");
  assertEquals(r.kind, "ok");
  if (r.kind === "ok") {
    assertEquals(r.lang, "ru");
    assertEquals(r.question.rubric.map((p) => p.id), ["p1", "p2"]);
    assertEquals(r.question.reference_answer, "Эталон.");
  }
  assertEquals(seen[0].url, `${URL_}/rest/v1/decks?select=version&id=eq.d`);
  assertEquals(seen[0].headers.get("authorization"), `Bearer ${USER_TOKEN}`);
  assertEquals(seen[0].headers.get("apikey"), ANON);
  assertEquals(seen[1].url, `${URL_}/storage/v1/object/decks/d/v2.json`);
  assertEquals(seen[1].headers.get("authorization"), `Bearer ${SERVICE}`);
  // Ключ service role не уходит в запрос с JWT пользователя; редиректы запрещены.
  assertFalse(JSON.stringify([...seen[0].headers]).includes(SERVICE));
  assert(seen.every((s) => s.redirect === "error"));
});

Deno.test("DeckSource: кэш файла по id@version, но доступ проверяется каждый раз", async () => {
  const seen: Seen[] = [];
  let visible: number | null = 2;
  const routes = deckRoutes();
  const src = new DeckSource({
    supabaseUrl: URL_,
    anonKey: ANON,
    serviceKey: SERVICE,
    fetchFn: fakeFetch(
      (u) =>
        u.includes("/rest/v1/decks")
          ? Response.json(visible === null ? [] : [{ version: visible }])
          : routes(u),
      seen,
    ),
  });
  await src.lookup(USER_TOKEN, "d", 2, "d.i.q2");
  await src.lookup(USER_TOKEN, "d", 2, "d.i.q2");
  assertEquals(seen.filter((s) => s.url.includes("/storage/")).length, 1);
  assertEquals(seen.filter((s) => s.url.includes("/rest/")).length, 2);
  // Колоду скрыли (RLS) — кэш файла не помогает.
  visible = null;
  assertEquals(
    (await src.lookup(USER_TOKEN, "d", 2, "d.i.q2")).kind,
    "deck_not_found",
  );
});

Deno.test("DeckSource: кэш различает версии одной колоды", async () => {
  const seen: Seen[] = [];
  const src = new DeckSource({
    supabaseUrl: URL_,
    anonKey: ANON,
    serviceKey: SERVICE,
    fetchFn: fakeFetch((u) => {
      if (u.includes("/rest/v1/decks")) return Response.json([{ version: 3 }]);
      const v = Number(u.match(/v(\d+)\.json$/)![1]);
      return new Response(deckJson(v));
    }, seen),
  });
  assertEquals((await src.lookup(USER_TOKEN, "d", 2, "d.i.q2")).kind, "ok");
  assertEquals((await src.lookup(USER_TOKEN, "d", 3, "d.i.q2")).kind, "ok");
  assertEquals(
    seen.filter((s) => s.url.includes("/storage/")).map((s) => s.url.slice(-7)),
    ["v2.json", "v3.json"],
  );
});

Deno.test("DeckSource: версия новее текущей, нет файла, нет вопроса, не open", async () => {
  const mk = (o: Parameters<typeof deckRoutes>[0]) =>
    new DeckSource({
      supabaseUrl: URL_,
      anonKey: ANON,
      serviceKey: SERVICE,
      fetchFn: fakeFetch(deckRoutes(o)),
    });
  assertEquals(
    (await mk({}).lookup(USER_TOKEN, "d", 3, "d.i.q2")).kind,
    "deck_not_found",
  );
  assertEquals(
    (await mk({ visible: null }).lookup(USER_TOKEN, "d", 2, "d.i.q2")).kind,
    "deck_not_found",
  );
  assertEquals(
    (await mk({ file: null }).lookup(USER_TOKEN, "d", 2, "d.i.q2")).kind,
    "deck_not_found",
  );
  assertEquals(
    (await mk({}).lookup(USER_TOKEN, "d", 2, "d.i.q9")).kind,
    "question_not_found",
  );
  assertEquals(
    (await mk({}).lookup(USER_TOKEN, "d", 2, "d.i.q1")).kind,
    "not_open",
  );
  // Старая версия, которая есть в Storage, доступна (клиент мог не обновиться).
  assertEquals(
    (await mk({ visible: 5 }).lookup(USER_TOKEN, "d", 2, "d.i.q2")).kind,
    "ok",
  );
});

Deno.test("DeckSource: файл не той колоды или версии — ошибка, не догадка", async () => {
  for (
    const file of [deckJson(3), deckJson(2, { id: "other" }), "not json", "[]"]
  ) {
    const src = new DeckSource({
      supabaseUrl: URL_,
      anonKey: ANON,
      serviceKey: SERVICE,
      fetchFn: fakeFetch(deckRoutes({ file })),
    });
    await assertRejects(
      () => src.lookup(USER_TOKEN, "d", 2, "d.i.q2"),
      DeckInvalidError,
    );
  }
});

Deno.test("DeckSource: файл больше лимита и 400 Storage без not found — ошибки", async () => {
  const big = new DeckSource({
    supabaseUrl: URL_,
    anonKey: ANON,
    serviceKey: SERVICE,
    maxDeckBytes: 100,
    fetchFn: fakeFetch(deckRoutes()),
  });
  await assertRejects(
    () => big.lookup(USER_TOKEN, "d", 2, "d.i.q2"),
    DeckInvalidError,
  );
  const bad400 = new DeckSource({
    supabaseUrl: URL_,
    anonKey: ANON,
    serviceKey: SERVICE,
    fetchFn: fakeFetch((u) =>
      u.includes("/rest/v1/decks")
        ? Response.json([{ version: 2 }])
        : Response.json({ statusCode: "400", error: "InvalidKey" }, {
          status: 400,
        })
    ),
  });
  await assertRejects(
    () => bad400.lookup(USER_TOKEN, "d", 2, "d.i.q2"),
    UpstreamError,
  );
});

Deno.test("DeckSource: ошибка Supabase — UpstreamError без тела", async () => {
  const src = new DeckSource({
    supabaseUrl: URL_,
    anonKey: ANON,
    serviceKey: SERVICE,
    fetchFn: fakeFetch(() => new Response("секрет в теле", { status: 503 })),
  });
  const e = await assertRejects(
    () => src.lookup(USER_TOKEN, "d", 2, "d.i.q2"),
    UpstreamError,
  );
  assertEquals(e.status, 503);
  assertFalse(e.message.includes("секрет"));
});

Deno.test("DeckSource: ключ sb_secret_ уходит только в apikey", async () => {
  const seen: Seen[] = [];
  await new DeckSource({
    supabaseUrl: URL_,
    anonKey: ANON,
    serviceKey: "sb_secret_x",
    fetchFn: fakeFetch(deckRoutes(), seen),
  }).lookup(USER_TOKEN, "d", 2, "d.i.q2");
  assertEquals(seen[1].headers.get("apikey"), "sb_secret_x");
  assertEquals(seen[1].headers.get("authorization"), null);
});

Deno.test("parseOpenQuestion: строгая проверка рубрики", () => {
  const bad = [
    { ...OPEN, prompt: "" },
    { ...OPEN, payload: { ...OPEN.payload, reference_answer: " " } },
    { ...OPEN, payload: { ...OPEN.payload, rubric: [OPEN.payload.rubric[0]] } },
    {
      ...OPEN,
      payload: {
        ...OPEN.payload,
        rubric: OPEN.payload.rubric.map((r) => ({ ...r, required: false })),
      },
    },
    {
      ...OPEN,
      payload: {
        ...OPEN.payload,
        rubric: [OPEN.payload.rubric[0], {
          ...OPEN.payload.rubric[1],
          weight: 4,
        }],
      },
    },
    {
      ...OPEN,
      payload: {
        ...OPEN.payload,
        rubric: [OPEN.payload.rubric[0], { ...OPEN.payload.rubric[0] }],
      },
    },
  ];
  for (const q of bad) {
    let threw = false;
    try {
      parseOpenQuestion(q as Record<string, unknown>);
    } catch (e) {
      threw = e instanceof DeckInvalidError;
    }
    assert(threw, JSON.stringify(q));
  }
});

Deno.test("SupabaseAuth: пользователь по JWT; 401 и не-пользователь — null", async () => {
  const seen: Seen[] = [];
  const id = "11111111-1111-4111-8111-111111111111";
  const auth = (status: number, body: unknown) =>
    new SupabaseAuth({
      supabaseUrl: URL_,
      anonKey: ANON,
      serviceKey: SERVICE,
      fetchFn: fakeFetch(() => Response.json(body, { status }), seen),
    });
  assertEquals(
    await auth(200, { id, role: "authenticated", is_anonymous: true }).getUser(
      USER_TOKEN,
    ),
    { id },
  );
  assertEquals(seen[0].url, `${URL_}/auth/v1/user`);
  assertEquals(seen[0].headers.get("authorization"), `Bearer ${USER_TOKEN}`);
  assertEquals(seen[0].headers.get("apikey"), ANON);
  assertEquals(await auth(401, {}).getUser("x"), null);
  assertEquals(await auth(403, {}).getUser("x"), null);
  assertEquals(await auth(200, { id, role: "anon" }).getUser("x"), null);
  assertEquals(
    await auth(200, { id: "nope", role: "authenticated" }).getUser("x"),
    null,
  );
  await assertRejects(() => auth(500, {}).getUser("x"), UpstreamError);
});

Deno.test("SupabaseGradingStore: RPC лимита, кэш и журнал — ключом service role", async () => {
  const seen: Seen[] = [];
  const store = new SupabaseGradingStore({
    supabaseUrl: URL_,
    anonKey: ANON,
    serviceKey: SERVICE,
    fetchFn: fakeFetch((url) => {
      if (url.includes("rpc/grading_quota_take")) {
        return Response.json([{
          allowed: false,
          reason: "quota",
          model_calls: 30,
          requests: 31,
          day: "2026-10-12",
          reset_at: "2026-10-13T00:00:00+00:00",
        }]);
      }
      if (url.includes("grading_cache?select")) return Response.json([]);
      return new Response(null, { status: 201 });
    }, seen),
  });
  const t = await store.take("u", true, {
    callLimit: 30,
    requestLimit: 300,
    budgetUsd: 1,
    reserveUsd: 0.002,
    unknownCostUsd: 0.001,
  });
  assertEquals(t, {
    allowed: false,
    reason: "quota",
    model_calls: 30,
    requests: 31,
    day: "2026-10-12",
    reset_at: "2026-10-13T00:00:00.000Z",
  });
  assertEquals(JSON.parse(seen[0].body!), {
    p_user_id: "u",
    p_model_call: true,
    p_call_limit: 30,
    p_request_limit: 300,
    p_budget_usd: 1,
    p_reserve_usd: 0.002,
  });
  assertEquals(await store.getCache("ab".repeat(32), "grade-v2"), null);
  assertEquals(
    seen[1].url,
    `${URL_}/rest/v1/grading_cache?select=*&key=eq.${
      "ab".repeat(32)
    }&prompt_version=eq.grade-v2`,
  );
  await store.refund("u", "2026-10-12");
  assertEquals(JSON.parse(seen[2].body!), {
    p_user_id: "u",
    p_day: "2026-10-12",
  });
  await store.settle("2026-10-12", 0.002, 0.00019);
  assertEquals(seen[3].url, `${URL_}/rest/v1/rpc/grading_budget_settle`);
  assertEquals(JSON.parse(seen[3].body!), {
    p_day: "2026-10-12",
    p_reserve_usd: 0.002,
    p_actual_usd: 0.00019,
  });
  for (const s of seen) {
    assertEquals(s.headers.get("authorization"), `Bearer ${SERVICE}`);
    assertEquals(s.headers.get("apikey"), SERVICE);
    assertEquals(s.redirect, "error");
  }
});

Deno.test("SupabaseGradingStore: ошибка — UpstreamError со статусом", async () => {
  const store = new SupabaseGradingStore({
    supabaseUrl: URL_,
    anonKey: ANON,
    serviceKey: SERVICE,
    fetchFn: fakeFetch(() => new Response("{}", { status: 409 })),
  });
  const e = await assertRejects(
    () => store.recordUsage({} as Parameters<typeof store.recordUsage>[0]),
    UpstreamError,
  );
  assertEquals(e.status, 409);
});
