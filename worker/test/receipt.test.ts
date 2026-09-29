import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildRequest, normalize, parseJsonObject } from '../src/receipt.ts';

test('a clean answer becomes paise, with the tax split kept', () => {
  const receipt = normalize({
    merchant: '  Third Wave Coffee  Roasters ',
    date: '2026-09-12',
    total: 525,
    cgst: 12.5,
    sgst: '12.50',
    igst: null,
    gst_rate: 5,
    gstin: '29aaect4478m1zk',
    payment: 'upi',
    category: 'food',
    items: [{ name: 'Cappuccino x2', amount: 340 }, { name: 'Almond Croissant', amount: '160.00' }],
  });
  assert.deepEqual(receipt, {
    merchant: 'Third Wave Coffee Roasters',
    date: '2026-09-12',
    totalPaise: 52500,
    cgstPaise: 1250,
    sgstPaise: 1250,
    igstPaise: null,
    gstRate: 5,
    gstin: '29AAECT4478M1ZK',
    payment: 'upi',
    category: 'food',
    items: [
      { name: 'Cappuccino x2', amountPaise: 34000 },
      { name: 'Almond Croissant', amountPaise: 16000 },
    ],
  });
});

test('made-up or malformed values are dropped, not passed on', () => {
  const receipt = normalize({
    merchant: 'DMart',
    date: '2026-09-31',
    total: '₹1,745.00',
    cgst: 5000,
    sgst: 5000,
    gst_rate: 7,
    gstin: 'NOT-A-GSTIN',
    payment: 'bitcoin',
    category: 'toys',
    items: 'none',
  });
  assert.equal(receipt?.date, null, '31 September does not exist');
  assert.equal(receipt?.totalPaise, 174500);
  assert.equal(receipt?.cgstPaise, null, 'tax larger than the bill is a misread');
  assert.equal(receipt?.gstRate, null, '7% is not a GST slab');
  assert.equal(receipt?.gstin, null);
  assert.equal(receipt?.payment, null);
  assert.equal(receipt?.category, null);
  assert.deepEqual(receipt?.items, []);
});

test('an answer with nothing useful is treated as unreadable', () => {
  assert.equal(normalize({ merchant: null, total: null, date: null }), null);
  assert.equal(normalize('I cannot read this image'), null);
  assert.equal(normalize(null), null);
});

test('the JSON is found even inside code fences or prose', () => {
  assert.deepEqual(parseJsonObject('```json\n{"total": 10}\n```'), { total: 10 });
  assert.deepEqual(parseJsonObject('Here you go: {"total": 10} Hope that helps.'), { total: 10 });
  assert.equal(parseJsonObject('no json here'), null);
  assert.equal(parseJsonObject(42), null);
});

test('requests ask only for providers that keep no data, text before image', () => {
  const request = buildRequest('qwen/qwen3.7-flash', 'AAAA', 'image/jpeg');
  assert.equal(request.provider.data_collection, 'deny');
  assert.equal(request.provider.require_parameters, true);
  assert.equal(request.response_format.type, 'json_object');
  const [text, image] = request.messages[0].content;
  assert.equal(text.type, 'text');
  assert.deepEqual(image, { type: 'image_url', image_url: { url: 'data:image/jpeg;base64,AAAA' } });
});
