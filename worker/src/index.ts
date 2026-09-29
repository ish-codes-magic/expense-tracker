// Slip's receipt reader: the app sends a photo here, this Worker asks a
// cheap vision model on OpenRouter to read it, checks the answer, and sends
// back the fields. The OpenRouter key lives only here, never in the app.

import { buildRequest, normalize, parseJsonObject } from './receipt.ts';

interface Env {
  OPENROUTER_API_KEY: string;
  APP_TOKEN: string;
  MODEL: string;
  PER_DEVICE: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

// A compressed receipt photo is 200–700 KB; this leaves generous room.
const MAX_BASE64_LENGTH = 4_000_000;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== 'POST' || url.pathname !== '/read') return reply({ error: 'not_found' }, 404);
    if (!env.OPENROUTER_API_KEY || !env.APP_TOKEN) return reply({ error: 'not_configured' }, 503);

    if (!sameSecret(request.headers.get('Authorization') ?? '', `Bearer ${env.APP_TOKEN}`)) {
      return reply({ error: 'unauthorized' }, 401);
    }

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

    // Only timing, size and cost are logged; never what's on the receipt.
    console.log(JSON.stringify({
      status: upstream.status,
      model: result?.model,
      provider: result?.provider,
      ms: Date.now() - started,
      promptTokens: result?.usage?.prompt_tokens,
      completionTokens: result?.usage?.completion_tokens,
      costUsd: result?.usage?.cost,
      error: result?.error?.message,
    }));

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
