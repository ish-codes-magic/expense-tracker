// What the reader asks the model for, and how its answer is checked before
// it goes back to the app. Pure functions, so they can be tested without
// Cloudflare or OpenRouter.

export const CATEGORIES = ['food', 'groceries', 'transport', 'shopping', 'utilities', 'health'] as const;
export const PAYMENTS = ['upi', 'credit_card', 'debit_card', 'cash', 'net_banking', 'other'] as const;
// GST slabs, including the older 12% and 28% and the 3% on gold.
const GST_RATES = new Set([0, 3, 5, 12, 18, 28, 40]);

export type Category = (typeof CATEGORIES)[number];
export type Payment = (typeof PAYMENTS)[number];

/** Money is sent to the app in paise, as the app stores it. */
export interface ReadReceipt {
  merchant: string | null;
  date: string | null;
  totalPaise: number | null;
  cgstPaise: number | null;
  sgstPaise: number | null;
  igstPaise: number | null;
  gstRate: number | null;
  gstin: string | null;
  payment: Payment | null;
  category: Category | null;
  items: { name: string; amountPaise: number }[];
}

export const PROMPT = `You read Indian shop receipts and invoices from a photo.
Return only a JSON object with exactly these keys:
{
  "merchant": the shop or brand name as printed at the top, or null,
  "date": the bill date as "YYYY-MM-DD" (Indian bills put the day first: 05/09/2026 is 2026-09-05), or null,
  "total": the final amount paid, in rupees: Grand Total / Net Amount / Amount Payable, after discounts and round-off; never cash tendered or change,
  "cgst": total CGST in rupees, or null,
  "sgst": total SGST or UTGST in rupees, or null,
  "igst": total IGST in rupees, or null,
  "gst_rate": the GST rate in percent if the whole bill uses one rate (CGST 2.5% + SGST 2.5% is 5), otherwise null,
  "gstin": the seller's 15-character GSTIN, or null,
  "payment": one of "upi", "credit_card", "debit_card", "cash", "net_banking", "other", or null if not shown,
  "category": one of "food", "groceries", "transport", "shopping", "utilities", "health",
  "items": [{"name": item name, "amount": line amount in rupees}] for items bought (not taxes, totals or discounts), at most 40
}
Copy numbers exactly as printed. Use null when something is not on the receipt instead of guessing.`;

/** The OpenRouter chat completions request for one photo. */
export function buildRequest(model: string, imageBase64: string, mime: string) {
  return {
    model,
    // Text first, then the image, as OpenRouter recommends.
    messages: [
      {
        role: 'user',
        content: [
          { type: 'text', text: PROMPT },
          { type: 'image_url', image_url: { url: `data:${mime};base64,${imageBase64}` } },
        ],
      },
    ],
    response_format: { type: 'json_object' },
    temperature: 0,
    max_tokens: 1500,
    provider: {
      // Only providers that don't keep or train on what they're sent, and
      // that honour JSON mode.
      data_collection: 'deny',
      require_parameters: true,
    },
  };
}

/** The JSON object in a model's reply, even if wrapped in ``` fences or prose. */
export function parseJsonObject(content: unknown): unknown {
  if (typeof content !== 'string') return null;
  const start = content.indexOf('{');
  const end = content.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(content.slice(start, end + 1));
  } catch {
    return null;
  }
}

/**
 * Checks and converts the model's answer. Anything malformed becomes null
 * rather than reaching the app; the app's own checks then mark what's left.
 * Returns null when nothing useful was read at all.
 */
export function normalize(raw: unknown): ReadReceipt | null {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const r = raw as Record<string, unknown>;

  const total = paise(r.total);
  let cgst = paise(r.cgst);
  let sgst = paise(r.sgst);
  let igst = paise(r.igst);
  // Tax can never be the whole bill; if it is, the model misread something.
  const tax = (cgst ?? 0) + (sgst ?? 0) + (igst ?? 0);
  if (total !== null && tax >= total) cgst = sgst = igst = null;

  const rate = typeof r.gst_rate === 'number' ? Math.round(r.gst_rate) : null;

  const result: ReadReceipt = {
    merchant: text(r.merchant, 80),
    date: isoDate(r.date),
    totalPaise: total !== null && total > 0 ? total : null,
    cgstPaise: cgst,
    sgstPaise: sgst,
    igstPaise: igst,
    gstRate: rate !== null && GST_RATES.has(rate) ? rate : null,
    gstin: gstin(r.gstin),
    payment: oneOf(PAYMENTS, r.payment),
    category: oneOf(CATEGORIES, r.category),
    items: Array.isArray(r.items)
      ? r.items
          .slice(0, 40)
          .map((item) => {
            const i = (item ?? {}) as Record<string, unknown>;
            const name = text(i.name, 80);
            const amount = paise(i.amount);
            return name && amount !== null ? { name, amountPaise: amount } : null;
          })
          .filter((item): item is { name: string; amountPaise: number } => item !== null)
      : [],
  };

  return result.merchant || result.totalPaise || result.date ? result : null;
}

function paise(value: unknown): number | null {
  const n = typeof value === 'string' ? Number(value.replace(/[₹,\s]/g, '')) : value;
  if (typeof n !== 'number' || !Number.isFinite(n) || n < 0 || n > 10_000_000) return null;
  return Math.round(n * 100);
}

function text(value: unknown, maxLength: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.replace(/\s+/g, ' ').trim();
  return trimmed ? trimmed.slice(0, maxLength) : null;
}

function isoDate(value: unknown): string | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00Z`);
  // Rejects 2026-09-31, which Date quietly rolls into October.
  return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value) ? value : null;
}

function gstin(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const cleaned = value.toUpperCase().replace(/[^A-Z0-9]/g, '');
  return /^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(cleaned) ? cleaned : null;
}

function oneOf<T extends string>(allowed: readonly T[], value: unknown): T | null {
  return typeof value === 'string' && (allowed as readonly string[]).includes(value) ? (value as T) : null;
}
