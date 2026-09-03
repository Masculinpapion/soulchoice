// 03.09.2026 — Ödeme çekirdeği AKIŞ testleri (kalite teşhisi: para akışının %93'ü testsizdi).
// Gerçek banka/DB yok: sahte fetch (Точка cevapları) + sahte db (queryObject kayıt/oynatma).
// Kapsanan senaryolar: çifte çekim koruması (ön-mutabakat), banka ulaşılamazken fail-closed,
// net başarı → tek grant, net hata → charge_fail, belirsiz → charge_unknown kilidi,
// webhook yarışında grant'ın tekrar uygulanmaması.
import { assertEquals, assert } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { attemptCharge, reconcileOnly, grantOrder, type ChargeSub, type ChargeDeps, type DbLike } from '../../supabase/functions/_shared/billing-charge.ts'

const SUB: ChargeSub = { id: 'sub-1', user_id: 'user-1', tochka_subscription_id: 'op-123', status: 'active', price_paid: 1000, retry_count: 0 }

/** Sahte DB: SQL metnine göre cevap üretir, her sorguyu kaydeder. */
function fakeDb(state: { knownOrders?: string[]; insertConflict?: boolean } = {}): DbLike & { log: string[]; events: string[] } {
  const log: string[] = []
  const events: string[] = []
  return {
    log, events,
    async queryObject<T = Record<string, unknown>>(sql: string, args?: unknown[]): Promise<{ rows: T[] }> {
      log.push(sql.replace(/\s+/g, ' ').trim().slice(0, 60))
      if (sql.includes('insert into billing_events')) { events.push(String(args?.[2])); return { rows: [] } }
      if (sql.includes('select order_id from payments')) {
        return { rows: (state.knownOrders ?? []).map((o) => ({ order_id: o })) as T[] }
      }
      if (sql.includes('insert into payments')) {
        return { rows: (state.insertConflict ? [] : [{ id: 'pay-1' }]) as T[] }
      }
      if (sql.includes('update users')) return { rows: [{ premium_until: new Date('2026-10-03T09:00:00Z') }] as T[] }
      return { rows: [] }
    },
  }
}

/** Sahte banka: GET operation → verilen Order listesi; POST charge → verilen cevap. */
function fakeBank(opts: { orders?: unknown[] | null; charge?: { status: number; body: string }; ordersAfterCharge?: unknown[] }): ChargeDeps & { calls: string[] } {
  const calls: string[] = []
  let charged = false
  return {
    calls,
    sleep: async () => {},
    async fetcher(url: string, init?: RequestInit) {
      calls.push((init?.method ?? 'GET') + ' ' + url.replace(/^https?:\/\/[^/]+/, ''))
      if (url.includes('/payments/')) {
        if (opts.orders === null) return new Response('down', { status: 503 })
        const orders = charged && opts.ordersAfterCharge ? opts.ordersAfterCharge : (opts.orders ?? [])
        return new Response(JSON.stringify({ Data: { Operation: [{ operationId: 'op-123', purpose: 'Подписка', Order: orders }] } }), { status: 200 })
      }
      if (url.includes('/charge')) {
        charged = true
        const c = opts.charge ?? { status: 200, body: JSON.stringify({ Data: { result: true } }) }
        return new Response(c.body, { status: c.status })
      }
      return new Response('nf', { status: 404 })
    },
  }
}

const approval = (id: string, t = '2026-09-03T08:00:00Z') => ({ orderId: id, type: 'approval', amount: 1000, time: t })

Deno.test('ön-mutabakat: bankada işlenmemiş çekim varsa KAYDET, yeni çekim YAPMA (çifte çekim koruması)', async () => {
  const db = fakeDb({ knownOrders: ['o-old'] })
  const bank = fakeBank({ orders: [approval('o-old', '2026-08-03T08:00:00Z'), approval('o-new')] })
  const r = await attemptCharge(db, SUB, 30, 'cron', bank)
  assertEquals(r.outcome, 'reconciled')
  assert(!bank.calls.some((c) => c.includes('/charge')), 'charge çağrılmamalı: ' + bank.calls.join(','))
  assert(db.events.includes('charge_ok'), 'charge_ok olayı (reconcile) yazılmalı: ' + db.events.join(','))
})

Deno.test('banka ulaşılamazken fail-closed: çekme, pending_verify yaz', async () => {
  const db = fakeDb()
  const bank = fakeBank({ orders: null })
  const r = await attemptCharge(db, SUB, 30, 'cron', bank)
  assertEquals(r.outcome, 'pending_verify')
  assert(!bank.calls.some((c) => c.includes('/charge')))
  assertEquals(db.events, ['charge_pending_verify'])
})

Deno.test('net başarı: charge_attempt ÖNCE yazılır, order görünür görünmez TEK grant', async () => {
  const db = fakeDb({ knownOrders: [] })
  const bank = fakeBank({ orders: [], ordersAfterCharge: [approval('o-1')] })
  const r = await attemptCharge(db, SUB, 30, 'cron', bank)
  assertEquals(r.outcome, 'charged')
  assertEquals(db.events[0], 'charge_attempt')
  assertEquals(db.events.filter((e) => e === 'charge_ok').length, 1)
  assertEquals(db.log.filter((l) => l.startsWith('insert into payments')).length, 1)
})

Deno.test('net hata (Errors alanı / 4xx): charge_fail, grant yok', async () => {
  const db = fakeDb({ knownOrders: [] })
  const bank = fakeBank({ orders: [], charge: { status: 400, body: JSON.stringify({ Errors: [{ code: 'X' }] }) } })
  const r = await attemptCharge(db, SUB, 30, 'cron', bank)
  assertEquals(r.outcome, 'fail')
  assertEquals(db.events, ['charge_attempt', 'charge_fail'])
})

Deno.test('belirsiz cevap (200 ama result yok): charge_unknown → kilit', async () => {
  const db = fakeDb({ knownOrders: [] })
  const bank = fakeBank({ orders: [], charge: { status: 200, body: '{"Data":{}}' } })
  const r = await attemptCharge(db, SUB, 30, 'cron', bank)
  assertEquals(r.outcome, 'unknown')
  assertEquals(db.events, ['charge_attempt', 'charge_unknown'])
})

Deno.test('ağ hatası çekimde: fail (güvenli varsayım), sonraki ön-mutabakat yakalar', async () => {
  const db = fakeDb({ knownOrders: [] })
  const bank = fakeBank({ orders: [] })
  const throwing: ChargeDeps = { sleep: bank.sleep, fetcher: async (url, init) => (url.includes('/charge') ? Promise.reject(new Error('ECONNRESET')) : bank.fetcher(url, init)) }
  const r = await attemptCharge(db, SUB, 30, 'cron', throwing)
  assertEquals(r.outcome, 'fail')
})

Deno.test('başarılı charge ama order 5 denemede görünmedi: pending_verify (para durumu bilinmiyor, ikinci çekim yok)', async () => {
  const db = fakeDb({ knownOrders: [] })
  const bank = fakeBank({ orders: [], ordersAfterCharge: [] })
  const r = await attemptCharge(db, SUB, 30, 'cron', bank)
  assertEquals(r.outcome, 'pending_verify')
  assertEquals(bank.calls.filter((c) => c.includes('/payments/')).length, 1 + 5)
})

Deno.test('webhook yarışı: payments insert çakışırsa grant uzatma yapmaz (null)', async () => {
  const db = fakeDb({ insertConflict: true })
  const until = await grantOrder(db, SUB, approval('o-9'), { purpose: 'x' }, 30, 'cron')
  assertEquals(until, null)
  assert(!db.log.some((l) => l.startsWith('update users')), 'premium uzatılmamalı')
})

Deno.test('reconcileOnly: bilinen orderlar tekrar işlenmez', async () => {
  const db = fakeDb({ knownOrders: ['o-1', 'o-2'] })
  const bank = fakeBank({ orders: [approval('o-1'), approval('o-2')] })
  const r = await reconcileOnly(db, SUB, 30, 'retry', bank)
  assertEquals(r.outcome, 'nothing')
  assertEquals(db.events.length, 0)
})
