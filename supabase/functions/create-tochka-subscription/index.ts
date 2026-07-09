// create-tochka-subscription — F2: grafiksiz (recurring:true) Точка aboneliği başlatır.
// Akış: auth → zorunlu e-posta + oferta onayı → P9 kuralları → Точка create → DB kayıtları → link.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''

const TOCHKA_API = 'https://enter.tochka.com/uapi'
const TOCHKA_JWT = Deno.env.get('TOCHKA_JWT_TOKEN') ?? ''
const CUSTOMER_CODE = Deno.env.get('TOCHKA_CUSTOMER_CODE') ?? '305892846'
const MERCHANT_ID = Deno.env.get('TOCHKA_MERCHANT_ID') ?? '200000000040619'
// Banka test protokolü: sadece TEST_PAYMENT_KEY eşleşirse tutar override edilir (1-100₽)
const TEST_PAYMENT_KEY = Deno.env.get('TEST_PAYMENT_KEY') ?? ''

const VALID_SOURCES = ['web', 'android', 'ios_app']
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function json(status: number, obj: unknown) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    if (!TOCHKA_JWT) return json(500, { error: 'tochka_not_configured' })

    const authHeader = req.headers.get('Authorization') ?? ''
    const userRes = await fetch(SUPABASE_URL + '/auth/v1/user', {
      headers: { apikey: ANON_KEY, Authorization: authHeader },
    })
    if (!userRes.ok) return json(401, { error: 'unauthorized' })
    const user = await userRes.json()
    if (!user?.id) return json(401, { error: 'unauthorized' })

    const body = await req.json().catch(() => ({}))
    const source = VALID_SOURCES.includes(body?.source) ? body.source : 'web'
    const email = String(body?.email ?? '').trim().toLowerCase()
    const ofertaVersion = String(body?.oferta_version ?? '').trim()

    // KARAR 3: e-posta zorunlu; F2-3: oferta onayı kanıtsız abonelik açılmaz
    if (!EMAIL_RE.test(email)) return json(400, { error: 'email_required' })
    if (!ofertaVersion) return json(400, { error: 'consent_required' })

    let testAmount: number | null = null
    if (body?.testAmount != null) {
      if (!TEST_PAYMENT_KEY || body?.testKey !== TEST_PAYMENT_KEY) return json(403, { error: 'forbidden' })
      testAmount = Number(body.testAmount)
      if (!Number.isFinite(testAmount) || testAmount < 1 || testAmount > 100) {
        return json(400, { error: 'bad_test_amount' })
      }
    }

    const db = new Client(DB_URL)
    await db.connect()
    try {
      // P9 + tutarlılık kuralları
      const existing = await db.queryObject<{
        id: string
        status: string
        auto_renew: boolean
        created_at: Date
        payment_link: string | null
        operation_id: string | null
      }>(
        `select s.id, s.status, s.auto_renew, s.created_at, p.payment_link, p.operation_id
           from subscriptions s
           left join payments p
             on p.subscription_id = s.id and p.charge_type = 'subscription_initial'
          where s.user_id = $1
            and s.status in ('pending_binding', 'active', 'past_due', 'cancelled')
          order by s.created_at desc
          limit 1`,
        [user.id],
      )
      const sub = existing.rows[0]
      if (sub) {
        if (sub.status === 'active' || sub.status === 'past_due') {
          return json(409, { error: 'already_subscribed' })
        }
        if (sub.status === 'cancelled') {
          // Premium dönemi sürüyorsa yeni ödeme değil "devam et" (KARAR 4)
          const prem = await db.queryObject<{ premium_until: Date | null }>(
            `select premium_until from users where id = $1`,
            [user.id],
          )
          const until = prem.rows[0]?.premium_until
          if (until && new Date(until) > new Date()) {
            return json(409, { error: 'use_resume', premium_until: until })
          }
        }
        if (sub.status === 'pending_binding') {
          const ageMs = Date.now() - new Date(sub.created_at).getTime()
          if (ageMs < 7 * 24 * 3600 * 1000 && sub.payment_link) {
            // Link 7 gün geçerli: yenisini üretme, aynısını döndür (P9 rate limit görevi de görür)
            return json(200, { paymentLink: sub.payment_link, operationId: sub.operation_id, reused: true })
          }
          // Süresi geçmiş pending_binding: kapat, yenisi açılacak
          await db.queryObject(
            `update subscriptions set status = 'expired' where id = $1 and status = 'pending_binding'`,
            [sub.id],
          )
        }
      }

      const cfg = await db.queryObject<{ price_rub: number }>(`select price_rub from billing_config where id = 1`)
      const amount = testAmount ?? cfg.rows[0]?.price_rub ?? 1000
      const isTest = testAmount != null
      const purpose = isTest
        ? 'Тест подписки SoulChoice Premium (автопродление)'
        : 'Подписка SoulChoice Premium (автопродление)'

      const tochkaRes = await fetch(TOCHKA_API + '/acquiring/v1.0/subscriptions', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + TOCHKA_JWT, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          Data: {
            customerCode: CUSTOMER_CODE,
            merchantId: MERCHANT_ID,
            amount: amount.toFixed(2),
            purpose,
            recurring: true,
            redirectUrl: 'https://soulchoice.app/premium?sub=ok',
            failRedirectUrl: 'https://soulchoice.app/premium?sub=fail',
          },
        }),
      })
      const tochkaJson = await tochkaRes.json()
      const op = tochkaJson?.Data
      if (!tochkaRes.ok || !op?.operationId || !op?.paymentLink) {
        console.error('tochka create subscription failed', JSON.stringify(tochkaJson))
        return json(502, { error: 'subscription_create_failed' })
      }

      await db.queryObject(`update users set billing_email = $2 where id = $1`, [user.id, email])

      const ins = await db.queryObject<{ id: string }>(
        `insert into subscriptions
           (user_id, status, provider, auto_renew, price_paid, currency, tochka_subscription_id)
         values ($1, 'pending_binding', 'tochka', true, $2, 'RUB', $3)
         returning id`,
        [user.id, Math.round(amount), op.operationId],
      )
      const subId = ins.rows[0].id

      await db.queryObject(
        `insert into payments
           (user_id, operation_id, order_id, amount, currency, source, status, purpose,
            payment_link, subscription_id, charge_type)
         values ($1, $2, '', $3, 'RUB', $4, 'pending', $5, $6, $7, 'subscription_initial')`,
        [user.id, op.operationId, amount, isTest ? 'test' : source, purpose, op.paymentLink, subId],
      )

      // Consent kanıtı (Mustafa şartı 09.07.2026): oferta_version + accepted_at + source ZORUNLU
      await db.queryObject(
        `insert into billing_events (subscription_id, user_id, event, detail)
         values ($1, $2, 'created', $3::jsonb),
                ($1, $2, 'consent_autopay', $4::jsonb)`,
        [
          subId,
          user.id,
          JSON.stringify({ operation_id: op.operationId, amount, source }),
          JSON.stringify({ oferta_version: ofertaVersion, accepted_at: new Date().toISOString(), source }),
        ],
      )

      return json(200, { paymentLink: op.paymentLink, operationId: op.operationId })
    } finally {
      await db.end()
    }
  } catch (e) {
    console.error('create-tochka-subscription error', e)
    return json(500, { error: String(e?.message ?? e) })
  }
})
