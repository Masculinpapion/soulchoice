import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

// Güvenlik modeli: webhook gövdesine GÜVENİLMEZ. Gövdeden sadece operationId
// alınır, ödemenin gerçek durumu Точка API'sinden kendi token'ımızla yeniden
// sorgulanır (APPROVED değilse hiçbir şey aktive edilmez). Böylece JWT imza
// doğrulaması olmadan da sahte webhook işe yaramaz.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''

const TOCHKA_API = 'https://enter.tochka.com/uapi'
const TOCHKA_JWT = Deno.env.get('TOCHKA_JWT_TOKEN') ?? ''
const CUSTOMER_CODE = Deno.env.get('TOCHKA_CUSTOMER_CODE') ?? '305892846'

const PREMIUM_DAYS = 30

function decodeBody(text: string): Record<string, unknown> | null {
  const t = text.trim()
  // Точка webhook'u JWT string olarak gelebilir — payload kısmını decode et
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

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok')

  try {
    const rawText = await req.text()
    const payload = decodeBody(rawText)
    const operationId = findOperationId(payload)
    if (!operationId) {
      // Bizi ilgilendirmeyen/parse edilemeyen bildirim — retry istemiyoruz
      console.log('webhook without operationId', rawText.slice(0, 500))
      return new Response('ok')
    }

    // Gerçek durumu bankadan doğrula
    const verifyRes = await fetch(
      TOCHKA_API + '/acquiring/v1.0/payments/' + encodeURIComponent(operationId) +
        '?customerCode=' + CUSTOMER_CODE,
      { headers: { Authorization: 'Bearer ' + TOCHKA_JWT } },
    )
    if (!verifyRes.ok) {
      console.error('tochka verify failed', operationId, verifyRes.status)
      return new Response('verify_failed', { status: 500 }) // Точка tekrar dener
    }
    const verifyJson = await verifyRes.json()
    const op = verifyJson?.Data?.Operation?.[0]
    if (op?.status !== 'APPROVED') {
      console.log('operation not approved, ignoring', operationId, op?.status)
      return new Response('ok')
    }

    const db = new Client(DB_URL)
    await db.connect()
    try {
      // İdempotent: sadece pending→paid geçişinde aktivasyon yapılır
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
          // Zaten işlenmiş — idempotent çıkış
          return new Response('ok')
        }
        // Uygulama dışında üretilmiş bir link (örn. kabinetten) — kayıt düş, aktivasyon yok
        await db.queryObject(
          `insert into payments (operation_id, amount, currency, source, status, purpose, raw, paid_at)
           values ($1, $2, 'RUB', 'web', 'paid', $3, $4::jsonb, now())
           on conflict (operation_id) do nothing`,
          [operationId, amount, op.purpose ?? null, JSON.stringify(op)],
        )
        return new Response('ok')
      }

      if (userId) {
        const prem = await db.queryObject<{ premium_until: Date }>(
          `update users
              set subscription_status = 'active',
                  premium_until = greatest(coalesce(premium_until, now()), now())
                                  + make_interval(days => $2)
            where id = $1
            returning premium_until`,
          [userId, PREMIUM_DAYS],
        )
        const expiresAt = prem.rows[0]?.premium_until ?? null
        await db.queryObject(
          `insert into subscriptions
             (user_id, status, provider, started_at, expires_at, auto_renew, price_paid, currency)
           values ($1, 'active', 'tochka', now(), $2, false, $3, 'RUB')`,
          [userId, expiresAt, Math.round(amount)],
        )
      }
    } finally {
      await db.end()
    }

    return new Response('ok')
  } catch (e) {
    console.error('tochka-webhook error', e)
    return new Response('error', { status: 500 }) // Точка tekrar dener
  }
})
