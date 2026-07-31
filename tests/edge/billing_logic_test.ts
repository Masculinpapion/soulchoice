// Para çekirdeği saf fonksiyon testleri (billing-charge.ts).
// Koşum: deno test --allow-read tests/edge/
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  approvedOrders,
  classifyChargeResponse,
  pendingRefundCount,
} from '../../supabase/functions/_shared/billing-charge.ts'

// ---- classifyChargeResponse: yalnız net başarı 'ok', belirsizlik DUR demek ----

Deno.test('classify: 200 + result:true → ok', () => {
  assertEquals(classifyChargeResponse(200, '{"Data":{"result":true}}'), 'ok')
})

Deno.test('classify: 200 + result:false → fail', () => {
  assertEquals(classifyChargeResponse(200, '{"Data":{"result":false}}'), 'fail')
})

Deno.test('classify: HTTP hata kodu → fail', () => {
  assertEquals(classifyChargeResponse(500, '{"Data":{"result":true}}'), 'fail')
  assertEquals(classifyChargeResponse(400, 'Bad Request'), 'fail')
})

Deno.test('classify: Errors alanı → fail (Точка hata zarfı)', () => {
  assertEquals(
    classifyChargeResponse(200, '{"Errors":[{"errorCode":"x"}]}'),
    'fail',
  )
})

Deno.test('classify: 200 ama tanınmayan gövde → unknown (para belirsiz, DUR)', () => {
  assertEquals(classifyChargeResponse(200, 'not json at all'), 'unknown')
  assertEquals(classifyChargeResponse(200, '{"Data":{}}'), 'unknown')
  assertEquals(classifyChargeResponse(200, '{}'), 'unknown')
})

// ---- approvedOrders: yalnız approval, zamana göre artan ----

Deno.test('approvedOrders: refund satırlarını dışlar, zamana göre sıralar', () => {
  const op = {
    Order: [
      { orderId: 'B', type: 'approval', amount: 2, time: '2026-07-09T10:49:55+03:00' },
      { orderId: 'R', type: 'refund', amount: 2, time: '2026-07-08T16:17:55+03:00' },
      { orderId: 'A', type: 'approval', amount: 2, time: '2026-07-08T16:16:08+03:00' },
      { orderId: '', type: 'approval', amount: 2, time: '2026-07-09T11:00:00+03:00' },
    ],
  }
  assertEquals(approvedOrders(op).map((o) => o.orderId), ['A', 'B'])
})

Deno.test('approvedOrders: null/boş operasyonda boş liste', () => {
  assertEquals(approvedOrders(null), [])
  assertEquals(approvedOrders({}), [])
})

// ---- pendingRefundCount: gerçek banka formatıyla (op 888189b9, 08.07 iadesi) ----

const REFUNDED_OP = {
  status: 'REFUNDED',
  Order: [
    { orderId: '5746916', type: 'approval', amount: 2, time: '2026-07-08T16:16:08+03:00' },
    { orderId: '5746946', type: 'refund', amount: 2, time: '2026-07-08T16:17:55+03:00' },
  ],
}

Deno.test('pendingRefundCount: işlenmemiş iade → 1', () => {
  assertEquals(pendingRefundCount(REFUNDED_OP, 0), 1)
})

Deno.test('pendingRefundCount: zaten işlenmiş → 0 (idempotent)', () => {
  assertEquals(pendingRefundCount(REFUNDED_OP, 1), 0)
})

Deno.test('pendingRefundCount: iadesiz operasyon → 0', () => {
  assertEquals(pendingRefundCount({ Order: [{ orderId: 'A', type: 'approval', amount: 2, time: 't' }] }, 0), 0)
  assertEquals(pendingRefundCount(null, 0), 0)
})

Deno.test('pendingRefundCount: fazla sayım negatife düşmez', () => {
  assertEquals(pendingRefundCount(REFUNDED_OP, 5), 0)
})
