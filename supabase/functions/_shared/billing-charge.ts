// _shared/billing-charge.ts — F2 çekim çekirdeği (TEK KAYNAK).
// billing-cron (FAZ B) ve manage-subscription 'retry' (P8) aynı akışı kullanır:
// ön-mutabakat (Order-diff; önceki çekim geçtiyse KAYDET-ÇEKME) → charge → savunmacı
// sınıflandırma (ok/fail/unknown) → senkron GET teyidi → grant. Точка S3 limiti için
// charge_attempt event'i çekimden ÖNCE yazılır — 20 saatlik sayaç bunu okur.
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const TOCHKA_API = 'https://enter.tochka.com/uapi'
const TOCHKA_JWT = Deno.env.get('TOCHKA_JWT_TOKEN') ?? ''
const CUSTOMER_CODE = Deno.env.get('TOCHKA_CUSTOMER_CODE') ?? '305892846'

export interface ChargeSub {
  id: string
  user_id: string
  tochka_subscription_id: string
  status: string
  price_paid: number
  retry_count: number
}

export interface TochkaOrder {
  orderId: string
  type: string
  amount: number
  time: string
}

export type ChargeOutcome =
  | { outcome: 'reconciled'; until: Date | null }
  | { outcome: 'charged'; until: Date | null }
  | { outcome: 'pending_verify'; raw: string }
  | { outcome: 'fail'; raw: string }
  | { outcome: 'unknown'; raw: string }

export async function getOperation(operationId: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(
    `${TOCHKA_API}/acquiring/v1.0/payments/${encodeURIComponent(operationId)}?customerCode=${CUSTOMER_CODE}`,
    { headers: { Authorization: 'Bearer ' + TOCHKA_JWT } },
  )
  if (!res.ok) return null
  const json = await res.json().catch(() => null)
  return json?.Data?.Operation?.[0] ?? null
}

export function approvedOrders(op: Record<string, unknown> | null): TochkaOrder[] {
  return (((op?.Order ?? []) as TochkaOrder[]))
    .filter((o) => o?.orderId && o?.type === 'approval')
    .sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime())
}

export async function logEvent(
  db: Client,
  subId: string | null,
  userId: string | null,
  event: string,
  detail: unknown,
) {
  await db.queryObject(
    `insert into billing_events (subscription_id, user_id, event, detail) values ($1, $2, $3, $4::jsonb)`,
    [subId, userId, event, JSON.stringify(detail ?? {})],
  )
}

// Webhook ile aynı grant formülü — idempotency (operation_id, order_id) çifti
export async function grantOrder(
  db: Client,
  sub: ChargeSub,
  order: TochkaOrder,
  op: Record<string, unknown>,
  periodDays: number,
  via: string,
): Promise<Date | null> {
  const ins = await db.queryObject<{ id: string }>(
    `insert into payments
       (user_id, operation_id, order_id, amount, currency, source, status, purpose,
        subscription_id, charge_type, paid_at, raw)
     select $1, $2, $3, $4, 'RUB',
            coalesce((select source from payments
                       where operation_id = $2 and charge_type = 'subscription_initial' limit 1), 'web'),
            'paid', $5, $6, 'subscription_renewal', $7::timestamptz, $8::jsonb
     on conflict (operation_id, order_id) do nothing
     returning id`,
    [sub.user_id, sub.tochka_subscription_id, order.orderId, order.amount,
     (op as { purpose?: string }).purpose ?? null, sub.id, order.time, JSON.stringify(op)],
  )
  if (ins.rows.length === 0) return null // webhook yarışı kazandı, uzatmayı o yaptı
  const prem = await db.queryObject<{ premium_until: Date }>(
    `update users
        set subscription_status = 'active', subscription_provider = 'tochka',
            premium_until = greatest(coalesce(premium_until, now()), now()) + make_interval(days => $2)
      where id = $1
      returning premium_until`,
    [sub.user_id, periodDays],
  )
  const until = prem.rows[0]?.premium_until ?? null
  await db.queryObject(
    `update subscriptions
        set status = 'active', expires_at = $2, next_billing_at = $2,
            retry_count = 0, grace_until = null
      where id = $1`,
    [sub.id, until],
  )
  await logEvent(db, sub.id, sub.user_id, 'charge_ok', {
    via, order_id: order.orderId, amount: order.amount,
    premium_until: until?.toISOString?.() ?? null,
  })
  return until
}

// Son 20 saatteki deneme sayısı (S3 banka limiti: redde günde max 2)
export async function attemptsLast20h(db: Client, subId: string): Promise<number> {
  const r = await db.queryObject<{ n: string }>(
    `select count(*) as n from billing_events
      where subscription_id = $1 and event = 'charge_attempt'
        and created_at > now() - interval '20 hours'`,
    [subId],
  )
  return Number(r.rows[0]?.n ?? 0)
}

// Son çekim sonucu 'charge_unknown' ise otomatik/manuel deneme kilitli (manuel çözüm bekler)
export async function isUnknownLocked(db: Client, subId: string): Promise<boolean> {
  const r = await db.queryObject<{ event: string }>(
    `select event from billing_events
      where subscription_id = $1 and event in ('charge_ok', 'charge_fail', 'charge_unknown')
      order by created_at desc limit 1`,
    [subId],
  )
  return r.rows[0]?.event === 'charge_unknown'
}

export async function attemptCharge(
  db: Client,
  sub: ChargeSub,
  periodDays: number,
  via: string,
): Promise<ChargeOutcome> {
  // 1) ÖN-MUTABAKAT: işlenmemiş çekim var mı? Varsa kaydet, ÇEKME (çifte çekim koruması)
  const preOp = await getOperation(sub.tochka_subscription_id)
  if (preOp) {
    const orders = approvedOrders(preOp)
    const known = await db.queryObject<{ order_id: string }>(
      `select order_id from payments where operation_id = $1 and order_id <> ''`,
      [sub.tochka_subscription_id],
    )
    const knownIds = new Set(known.rows.map((r) => r.order_id))
    const missing = orders.filter((o) => !knownIds.has(o.orderId))
    if (missing.length > 0) {
      let until: Date | null = null
      for (const o of missing) {
        until = (await grantOrder(db, sub, o, preOp, periodDays, via + '_reconcile')) ?? until
      }
      return { outcome: 'reconciled', until }
    }
  }

  // 2) Deneme kaydı ÖNCE (S3 sayacı çökme/yeniden koşmada bile doğru kalır)
  await logEvent(db, sub.id, sub.user_id, 'charge_attempt', {
    amount: sub.price_paid, via, retry_no: sub.retry_count + 1,
  })

  // 3) Charge + savunmacı sınıflandırma
  let cls: 'ok' | 'fail' | 'unknown' = 'unknown'
  let rawBody = ''
  try {
    const res = await fetch(
      `${TOCHKA_API}/acquiring/v1.0/subscriptions/${encodeURIComponent(sub.tochka_subscription_id)}/charge`,
      {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + TOCHKA_JWT, 'Content-Type': 'application/json' },
        body: JSON.stringify({ Data: { amount: Number(sub.price_paid).toFixed(2) } }),
      },
    )
    rawBody = (await res.text()).slice(0, 1000)
    let parsed: Record<string, unknown> | null = null
    try {
      parsed = JSON.parse(rawBody)
    } catch { /* parse edilemedi → aşağıda sınıflandırılır */ }
    const result = (parsed as { Data?: { result?: unknown } } | null)?.Data?.result
    if (res.status === 200 && result === true) cls = 'ok'
    else if (!res.ok || result === false || (parsed as { Errors?: unknown } | null)?.Errors) cls = 'fail'
    else cls = 'unknown' // 200 ama tanınmayan gövde — para durumu belirsiz, DUR
  } catch (e) {
    cls = 'fail' // ağ hatası: çekim gitmedi varsayımı güvenli; sonraki ön-mutabakat yakalar
    rawBody = String(e?.message ?? e)
  }

  if (cls === 'fail') {
    await logEvent(db, sub.id, sub.user_id, 'charge_fail', { raw: rawBody, via })
    return { outcome: 'fail', raw: rawBody }
  }
  if (cls === 'unknown') {
    await logEvent(db, sub.id, sub.user_id, 'charge_unknown', { raw: rawBody, via })
    return { outcome: 'unknown', raw: rawBody }
  }

  // 4) result:true → Order kaydını senkron teyit et
  await new Promise((r) => setTimeout(r, 15000))
  const op2 = await getOperation(sub.tochka_subscription_id)
  const orders2 = approvedOrders(op2).reverse() // en yeni önce
  const known2 = await db.queryObject<{ order_id: string }>(
    `select order_id from payments where operation_id = $1 and order_id <> ''`,
    [sub.tochka_subscription_id],
  )
  const known2Ids = new Set(known2.rows.map((r) => r.order_id))
  const fresh = orders2.find((o) => !known2Ids.has(o.orderId))
  if (fresh && op2) {
    const until = await grantOrder(db, sub, fresh, op2, periodDays, via)
    return { outcome: 'charged', until }
  }
  await logEvent(db, sub.id, sub.user_id, 'charge_pending_verify', { raw: rawBody, via })
  return { outcome: 'pending_verify', raw: rawBody }
}
