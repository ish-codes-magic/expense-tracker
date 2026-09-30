// Slip's receipt reader: the app sends a photo here, this Worker asks a
// cheap vision model on OpenRouter to read it, checks the answer, and sends
// back the fields. The OpenRouter key lives only here, never in the app.

import { buildRequest, normalize, parseJsonObject } from './receipt.ts';

interface Env {
  OPENROUTER_API_KEY: string;
  APP_TOKEN: string;
  MODEL: string;
  PER_DEVICE: { limit(options: { key: string }): Promise<{ success: boolean }> };
  DB: D1Database;
}

// The parts of Cloudflare's D1 API this Worker uses.
interface D1Database {
  prepare(sql: string): {
    bind(...values: unknown[]): { run(): Promise<unknown>; first<T>(): Promise<T | null>; all<T>(): Promise<{ results: T[] }> };
    first<T>(): Promise<T | null>;
    all<T>(): Promise<{ results: T[] }>;
  };
}

// A compressed receipt photo is 200–700 KB; this leaves generous room.
const MAX_BASE64_LENGTH = 4_000_000;

export default {
  async fetch(request: Request, env: Env, ctx: { waitUntil(promise: Promise<unknown>): void }): Promise<Response> {
    const url = new URL(request.url);
    const route = `${request.method} ${url.pathname}`;
    if (route !== 'POST /read' && route !== 'GET /usage') return reply({ error: 'not_found' }, 404);
    if (!env.OPENROUTER_API_KEY || !env.APP_TOKEN) return reply({ error: 'not_configured' }, 503);

    if (!sameSecret(request.headers.get('Authorization') ?? '', `Bearer ${env.APP_TOKEN}`)) {
      return reply({ error: 'unauthorized' }, 401);
    }

    if (route === 'GET /usage') return usage(env);

    // Each install sends a random id, so one phone can't use up everyone's
    // allowance. Six reads a minute is plenty for a person scanning a pile.
    const device = request.headers.get('X-Slip-Device') ?? '';
    if (!/^[0-9a-f-]{36}$/i.test(device)) return reply({ error: 'bad_device' }, 400);
    if (!(await env.PER_DEVICE.limit({ key: device })).success) return reply({ error: 'rate_limited' }, 429);

    let body: { image?: unknown; mime?: unknown };
    try {
      body = await request.json();
    } catch {
      return reply({ error: 'bad_request' }, 400);
    }
    const image = typeof body.image === 'string' ? body.image : '';
    const mime = body.mime === 'image/png' ? 'image/png' : 'image/jpeg';
    if (!image || image.length > MAX_BASE64_LENGTH) return reply({ error: 'bad_image' }, 400);

    const started = Date.now();
    const upstream = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${env.OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(buildRequest(env.MODEL, image, mime)),
    });
    const result = (await upstream.json().catch(() => null)) as OpenRouterResponse | null;

    // Only timing, size and cost are logged and recorded; never what's on
    // the receipt. The ledger write happens after the reply is sent.
    const record = {
      status: upstream.status,
      model: result?.model,
      provider: result?.provider,
      ms: Date.now() - started,
      promptTokens: result?.usage?.prompt_tokens,
      completionTokens: result?.usage?.completion_tokens,
      costUsd: result?.usage?.cost,
      error: result?.error?.message,
    };
    console.log(JSON.stringify(record));
    ctx.waitUntil(
      env.DB.prepare(
        'INSERT INTO reads (at, device, status, model, ms, prompt_tokens, completion_tokens, cost_usd) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      )
        .bind(new Date().toISOString(), device, record.status, record.model ?? null, record.ms,
          record.promptTokens ?? null, record.completionTokens ?? null, record.costUsd ?? null)
        .run()
        .catch((error: unknown) => console.log('ledger write failed', String(error))),
    );

    if (!upstream.ok || !result) return reply({ error: 'reader_failed' }, 502);
    const receipt = normalize(parseJsonObject(result.choices?.[0]?.message?.content));
    if (!receipt) return reply({ error: 'unreadable' }, 422);
    return reply({ receipt, model: result.model });
  },
};

interface OpenRouterResponse {
  model?: string;
  provider?: string;
  choices?: { message?: { content?: unknown } }[];
  usage?: { prompt_tokens?: number; completion_tokens?: number; cost?: number };
  error?: { message?: string };
}

/**
 * What Slip itself has spent, from its own ledger (days in Indian time),
 * next to what the OpenRouter key has spent in total, which includes any
 * other use of the same key.
 */
async function usage(env: Env): Promise<Response> {
  const ist = '+330 minutes';
  const totals = (where: string) =>
    env.DB.prepare(
      `SELECT COUNT(*) AS reads, SUM(status = 200) AS succeeded, COALESCE(SUM(cost_usd), 0) AS costUsd,
              AVG(ms) AS avgMs, AVG(prompt_tokens) AS avgPromptTokens, AVG(completion_tokens) AS avgCompletionTokens
       FROM reads WHERE ${where}`,
    ).first<Record<string, number>>();
  const [allTime, today, thisMonth, recent, keyInfo] = await Promise.all([
    totals('1 = 1'),
    totals(`date(at, '${ist}') = date('now', '${ist}')`),
    totals(`strftime('%Y-%m', at, '${ist}') = strftime('%Y-%m', 'now', '${ist}')`),
    env.DB.prepare(
      'SELECT at, status, model, ms, prompt_tokens AS promptTokens, completion_tokens AS completionTokens, cost_usd AS costUsd FROM reads ORDER BY id DESC LIMIT 20',
    ).all<Record<string, unknown>>(),
    fetch('https://openrouter.ai/api/v1/key', { headers: { Authorization: `Bearer ${env.OPENROUTER_API_KEY}` } })
      .then((r) => (r.ok ? r.json() : null))
      .catch(() => null) as Promise<{ data?: Record<string, unknown> } | null>,
  ]);
  const key = keyInfo?.data;
  return reply({
    slip: { allTime, today, thisMonth, recent: recent.results },
    openRouterKey: key
      ? {
          spentUsd: key.usage,
          spentTodayUsd: key.usage_daily,
          spentThisMonthUsd: key.usage_monthly,
          capUsd: key.limit,
          capRemainingUsd: key.limit_remaining,
        }
      : null,
  });
}

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

/** Compares secrets in constant time, so response timing reveals nothing. */
function sameSecret(given: string, expected: string): boolean {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  if (a.byteLength !== b.byteLength) return false;
  return crypto.subtle.timingSafeEqual(a, b);
}
