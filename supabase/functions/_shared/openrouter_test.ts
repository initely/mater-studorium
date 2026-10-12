import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { chatCompletion, OpenRouterError } from "./openrouter.ts";

const KEY = "test-key-not-real";

function fakeFetch(status: number, body: unknown, seen: RequestInit[] = []) {
  return ((_url: string, init: RequestInit) => {
    seen.push(init);
    return Promise.resolve(
      new Response(JSON.stringify(body), { status }),
    );
  }) as unknown as typeof fetch;
}

Deno.test("chatCompletion: тело запроса и разбор usage", async () => {
  const seen: RequestInit[] = [];
  const r = await chatCompletion({
    apiKey: KEY,
    model: "m/x",
    messages: [{ role: "user", content: "hi" }],
    responseFormat: { type: "json_object" },
    temperature: 0,
    seed: 7,
    fetchFn: fakeFetch(200, {
      id: "gen-1",
      provider: "P",
      choices: [{ message: { content: '{"a":1}' } }],
      usage: {
        prompt_tokens: 10,
        completion_tokens: 5,
        cost: 0.00001,
        completion_tokens_details: { reasoning_tokens: 2 },
      },
    }, seen),
  });
  assertEquals(r.content, '{"a":1}');
  assertEquals(r.usage, {
    prompt_tokens: 10,
    completion_tokens: 5,
    reasoning_tokens: 2,
    cost: 0.00001,
  });
  assertEquals(r.provider, "P");
  const body = JSON.parse(seen[0].body as string);
  assertEquals(body.temperature, 0);
  assertEquals(body.seed, 7);
  assertEquals(body.provider, { require_parameters: true });
  assertEquals(body.response_format, { type: "json_object" });
  assert(!("reasoning" in body));
});

Deno.test("chatCompletion: без temperature/seed поля не передаются", async () => {
  const seen: RequestInit[] = [];
  await chatCompletion({
    apiKey: KEY,
    model: "m/x",
    messages: [],
    fetchFn: fakeFetch(
      200,
      { choices: [{ message: { content: null } }] },
      seen,
    ),
  });
  const body = JSON.parse(seen[0].body as string);
  assert(!("temperature" in body) && !("seed" in body));
});

Deno.test("chatCompletion: ошибки типизированы и без ключа", async () => {
  const e429 = await assertRejects(
    () =>
      chatCompletion({
        apiKey: KEY,
        model: "m/x",
        messages: [],
        fetchFn: fakeFetch(429, { error: { message: "rate limited" } }),
      }),
    OpenRouterError,
  );
  assertEquals(e429.status, 429);
  assert(e429.retryable);
  assert(!e429.message.includes(KEY));

  const e400 = await assertRejects(
    () =>
      chatCompletion({
        apiKey: KEY,
        model: "m/x",
        messages: [],
        fetchFn: fakeFetch(400, { error: { message: "bad" } }),
      }),
    OpenRouterError,
  );
  assert(!e400.retryable);

  // 200 с полем error (ошибка провайдера) — тоже ошибка.
  await assertRejects(
    () =>
      chatCompletion({
        apiKey: KEY,
        model: "m/x",
        messages: [],
        fetchFn: fakeFetch(200, { error: { message: "upstream", code: 502 } }),
      }),
    OpenRouterError,
  );
});

Deno.test("chatCompletion: таймаут → OpenRouterError(0, retryable)", async () => {
  const hang = ((_u: string, init: RequestInit) =>
    new Promise((_, reject) => {
      init.signal?.addEventListener("abort", () =>
        reject(new DOMException("aborted", "AbortError")));
    })) as unknown as typeof fetch;
  const e = await assertRejects(
    () =>
      chatCompletion({
        apiKey: KEY,
        model: "m/x",
        messages: [],
        timeoutMs: 10,
        fetchFn: hang,
      }),
    OpenRouterError,
  );
  assertEquals(e.status, 0);
  assertEquals(e.message, "timeout");
  assert(e.retryable);
});
