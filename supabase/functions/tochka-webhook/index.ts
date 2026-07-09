// tochka-webhook v2 — F1 davranışı korunur + F2 abonelik desteği (Faz 0 bulgularına göre).
//
// Güvenlik modeli (F1'den): webhook gövdesine GÜVENİLMEZ. Gövdeden sadece operationId alınır,
// gerçek durum Точка API'sinden yeniden sorgulanır (APPROVED değilse hiçbir şey aktive edilmez).
//
// F2 modeli (Faz 0): abonelik çekimlerinde YENİ operasyon oluşmaz; aynı operationId'nin Order[]
// dizisine orderId'li satır eklenir. Abonelik operasyonu CofToken alanından tanınır.
// İdempotency anahtarı (operation_id, order_id) — UNIQUE kısıt Faz 2 migration'ında.
// Bilinmeyen CofToken'lı operasyona 500 dönülür (Точка retry) — orphan-insert tuzağı düzeltmesi.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''

const TOCHKA_API = 'https://enter.tochka.com/uapi'
const TOCHKA_JWT = Deno.env.get('TOCHKA_JWT_TOKEN') ?? ''
const CUSTOMER_CODE = Deno.env.get('TOCHKA_CUSTOMER_CODE') ?? '305892846'

const FALLBACK_PERIOD_DAYS = 30

function decodeBody(text: string): Record<string, unknown> | null {
  const t = text.trim()
  if (/^[\w-]+\.[\w-]+\.[\w-]+$/.test(t)) {
    try {
      const payload = t.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
      return JSON.parse(new TextDecoder().decode(
        Uint8Array.from(atob(payload), (c) => c.charCodeAt(0)),
      ))
    } catch {
      return null
    }
  }
  try {
    return JSON.parse(t)
  } catch {
    return null
  }
}

function findOperationId(obj: unknown): string | null {
  if (obj == null || typeof obj !== 'object') return null
  const rec = obj as Record<string, unknown>
  for (const key of ['operationId', 'operation_id']) {
    if (typeof rec[key] === 'string') return rec[key] as string
  }
  for (const v of Object.values(rec)) {
    const found = findOperationId(v)
    if (found) return found
  }
  return null
}

interface TochkaOrder {
  orderId: string
  type: string
  amount: number
  time: string
}

// premium uzatma + abonelik alanlarını tazeleme (initial ve renewal için ortak formül)
async function grantPeriod(
  db: Client,
  userId: string,
  subId: string,
  periodDays: number,
): Promise<Date | null> {
  const prem = await db.queryObject<{ premium_until: Date }>(
    `update users
        set subscription_status = 'active',
            subscription_provider = 'tochka',
            premium_until = greatest(coalesce(premium_until, now()), now())
                            + make_interval(days => $2)
      where id = $1
      returning premium_until`,
    [userId, periodDays],
  )
  if (prem.rows.length === 0) return null
  const until = prem.rows[0].premium_until
  await db.queryObject(
    `update subscriptions
        set status = 'active',
            expires_at = $2,
            next_billing_at = $2,
            retry_count = 0,
            grace_until = null
      where id = $1`,
    [subId, until],
  )
  return until
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok')

  try {
    const rawText = await req.text()
    const payload = decodeBody(rawText)
    const operationId = findOperationId(payload)
    if (!operationId) {
      console.log('webhook without operationId', rawText.slice(0, 500))
      return new Response('ok')
    }

    // Gerçek durumu bankadan doğrula
    const verifyRes = await fetch(
      TOCHKA_API + '/acquiring/v1.0/payments/' + encodeURIComponent(operationId) +
        '?customerCode=' + CUSTOMER_CODE,
      { headers: { Authorization: 'Bearer ' + TOCHKA_JWT } },
    )
    if (verifyRes.status >= 500) {
      console.error('tochka verify unavailable', operationId, verifyRes.status)
      return new Response('verify_failed', { status: 500 })
    }
    if (!verifyRes.ok) {
      // Bankada bulunamadı (404/424): Точка'nın kayıt testi sentetik operationId gönderir →
      // bilinmeyene 200 şart. Bizim pending kaydımız varsa yarış olabilir: 500 (retry).
      const pendingRes = await fetch(
        SUPABASE_URL + '/rest/v1/payments?operation_id=eq.' +
          encodeURIComponent(operationId) + '&status=eq.pending&select=id&limit=1',
        { headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY } },
      )
      const pending = await pendingRes.json().catch(() => [])
      if (Array.isArray(pending) && pending.length > 0) {
        console.error('verify failed for known pending op, will retry', operationId, verifyRes.status)
        return new Response('verify_failed', { status: 500 })
      }
      console.log('unknown operation, ignoring (probably registration test)', operationId, verifyRes.status)
      return new Response('ok')
    }
    const verifyJson = await verifyRes.json()
    const op = verifyJson?.Data?.Operation?.[0]
    if (op?.status !== 'APPROVED') {
      console.log('operation not approved, ignoring', operationId, op?.status)
      return new Response('ok')
    }

    const cofToken = op?.CofToken as { tokenCardId?: string; cardType?: string; maskedPan?: string } | undefined

    const db = new Client(DB_URL)
    await db.connect()
    try {
      // ============ F2: ABONELİK OPERASYONU (CofToken var) ============
      if (cofToken?.tokenCardId) {
        const subRes = await db.queryObject<{ id: string; user_id: string | null; status: string }>(
          `select id, user_id, status from subscriptions where tochka_subscription_id = $1`,
          [operationId],
        )
        if (subRes.rows.length === 0) {
          // Lokal kaydı olmayan abonelik operasyonu: create yarışı olabilir → Точка retry etsin.
          // (Orphan-insert YOK: sahipsiz paid satırı aboneliği uzatamaz, tuzak düzeltildi.)
          console.error('subscription op without local record, retry', operationId)
          return new Response('subscription_unknown', { status: 500 })
        }
        const sub = subRes.rows[0]
        if (!sub.user_id) {
          console.error('subscription without user, skipping', operationId)
          return new Response('ok')
        }

        const cfg = await db.queryObject<{ period_days: number }>(
          `select period_days from billing_config where id = 1`,
        )
        const periodDays = cfg.rows[0]?.period_days ?? FALLBACK_PERIOD_DAYS

        const orders = ((op.Order ?? []) as TochkaOrder[])
          .filter((o) => o?.orderId && o?.type === 'approval')
          .sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime())

        const known = await db.queryObject<{ order_id: string }>(
          `select order_id from payments where operation_id = $1 and order_id <> ''`,
          [operationId],
        )
        const knownIds = new Set(known.rows.map((r) => r.order_id))

        let bindingActivated = false
        for (const order of orders) {
          if (knownIds.has(order.orderId)) continue

          // İlk yeni order: bekleyen bağlama satırını (order_id='') sahiplenmeyi dene
          const claimed = await db.queryObject<{ id: string }>(
            `update payments
                set status = 'paid', paid_at = $3::timestamptz, order_id = $2, raw = $4::jsonb
              where operation_id = $1 and order_id = '' and status = 'pending'
              returning id`,
            [operationId, order.orderId, order.time, JSON.stringify(op)],
          )
          let applied = claimed.rows.length > 0
          let chargeType = 'subscription_initial'

          if (!applied) {
            // Renewal (veya bağlama satırı kaybolmuş): doğrudan ekle — (operation_id, order_id) idempotent
            chargeType = sub.status === 'pending_binding' ? 'subscription_initial' : 'subscription_renewal'
            const ins = await db.queryObject<{ id: string }>(
              `insert into payments
                 (user_id, operation_id, order_id, amount, currency, source, status, purpose,
                  subscription_id, charge_type, paid_at, raw)
               select $1, $2, $3, $4, 'RUB',
                      coalesce((select source from payments
                                 where operation_id = $2 and charge_type = 'subscription_initial' limit 1), 'web'),
                      'paid', $5, $6, $7, $8::timestamptz, $9::jsonb
               on conflict (operation_id, order_id) do nothing
               returning id`,
              [sub.user_id, operationId, order.orderId, order.amount,
               op.purpose ?? null, sub.id, chargeType, order.time, JSON.stringify(op)],
            )
            applied = ins.rows.length > 0
          }
          if (!applied) continue // yarışı cron kazandı — uzatma da onun tarafından yapıldı

          const until = await grantPeriod(db, sub.user_id, sub.id, periodDays)
          await db.queryObject(
            `insert into billing_events (subscription_id, user_id, event, detail)
             values ($1, $2, $3, $4::jsonb)`,
            [sub.id, sub.user_id, chargeType === 'subscription_initial' ? 'binding_paid' : 'charge_ok',
             JSON.stringify({ via: 'webhook', order_id: order.orderId, amount: order.amount,
                              premium_until: until?.toISOString?.() ?? null })],
          )
          if (chargeType === 'subscription_initial') bindingActivated = true
        }

        // Bağlamada abonelik meta verilerini tamamla
        if (bindingActivated || sub.status === 'pending_binding') {
          await db.queryObject(
            `update subscriptions
                set started_at = coalesce(started_at, now()),
                    card_masked_pan = $2,
                    card_type = $3,
                    auto_renew = true
              where id = $1`,
            [sub.id, cofToken.maskedPan ?? null, cofToken.cardType ?? null],
          )
        }
        return new Response('ok')
      }

      // ============ F1: TEK SEFERLİK ÖDEME (CofToken yok — mevcut davranış) ============
      const upd = await db.queryObject<{ user_id: string | null; amount: string }>(
        `update payments
            set status = 'paid', paid_at = now(), raw = $2::jsonb
          where operation_id = $1 and status = 'pending'
          returning user_id, amount`,
        [operationId, JSON.stringify(op)],
      )

      let userId: string | null = null
      let amount = Number(op.amount ?? 0)
      if (upd.rows.length > 0) {
        userId = upd.rows[0].user_id
        amount = Number(upd.rows[0].amount)
      } else {
        const existing = await db.queryObject(
          `select 1 from payments where operation_id = $1`,
          [operationId],
        )
        if (existing.rows.length > 0) {
          return new Response('ok') // zaten işlenmiş — idempotent
        }
        // Uygulama dışında üretilmiş link (örn. kabinetten) — kayıt düş, aktivasyon yok
        await db.queryObject(
          `insert into payments (operation_id, order_id, amount, currency, source, status, purpose, raw, paid_at)
           values ($1, '', $2, 'RUB', 'web', 'paid', $3, $4::jsonb, now())
           on conflict (operation_id, order_id) do nothing`,
          [operationId, amount, op.purpose ?? null, JSON.stringify(op)],
        )
        return new Response('ok')
      }

      if (userId) {
        const cfg = await db.queryObject<{ period_days: number }>(
          `select period_days from billing_config where id = 1`,
        )
        const periodDays = cfg.rows[0]?.period_days ?? FALLBACK_PERIOD_DAYS
        const prem = await db.queryObject<{ premium_until: Date }>(
          `update users
              set subscription_status = 'active',
                  premium_until = greatest(coalesce(premium_until, now()), now())
                                  + make_interval(days => $2)
            where id = $1
            returning premium_until`,
          [userId, periodDays],
        )
        if (prem.rows.length === 0) {
          console.error('paid but no users profile, premium not applied', operationId, userId)
        } else {
          const expiresAt = prem.rows[0].premium_until
          await db.queryObject(
            `insert into subscriptions
               (user_id, status, provider, started_at, expires_at, auto_renew, price_paid, currency)
             values ($1, 'active', 'tochka', now(), $2, false, $3, 'RUB')`,
            [userId, expiresAt, Math.round(amount)],
          )
        }
      }
      return new Response('ok')
    } finally {
      await db.end()
    }
  } catch (e) {
    console.error('tochka-webhook error', e)
    return new Response('error', { status: 500 }) // Точка tekrar dener
  }
})
