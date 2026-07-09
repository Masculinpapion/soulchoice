// manage-subscription — F2 abonelik yönetimi: durum / iptal (KARAR 4 yumuşak) / devam et.
// İptal SADECE lokaldir (auto_renew=false): çekimi yalnız biz tetiklediğimiz için %100 durdurur.
// Bankada iptal endpoint'i yok (Faz 0 bulgusu); kart bağı bankada kalır, oferta §2.1 açıklar.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'
import { sendBillingEmail } from '../_shared/billing-email.ts'
import { attemptCharge, attemptsLast20h, isUnknownLocked } from '../_shared/billing-charge.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''

function json(status: number, obj: unknown) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

function fmtDate(d: Date | string | null | undefined): string {
  if (!d) return ''
  const dt = new Date(d)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(dt.getDate())}.${p(dt.getMonth() + 1)}.${dt.getFullYear()}`
}

// Push best-effort: mevcut send-notification fn'i service key ile çağrılır, hata yutulur
async function sendPush(userId: string, title: string, body: string) {
  try {
    await fetch(SUPABASE_URL + '/functions/v1/send-notification', {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: 'Bearer ' + SERVICE_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ user_id: userId, title, body }),
    })
  } catch (e) {
    console.error('push failed', e?.message ?? e)
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const userRes = await fetch(SUPABASE_URL + '/auth/v1/user', {
      headers: { apikey: ANON_KEY, Authorization: authHeader },
    })
    if (!userRes.ok) return json(401, { error: 'unauthorized' })
    const user = await userRes.json()
    if (!user?.id) return json(401, { error: 'unauthorized' })

    const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {}
    const action = body?.action ?? 'status'

    const db = new Client(DB_URL)
    await db.connect()
    try {
      const subRes = await db.queryObject<{
        id: string
        status: string
        auto_renew: boolean
        next_billing_at: Date | null
        card_masked_pan: string | null
        card_type: string | null
        price_paid: number | null
        cancelled_at: Date | null
        tochka_subscription_id: string | null
        retry_count: number
      }>(
        `select id, status, auto_renew, next_billing_at, card_masked_pan, card_type,
                price_paid, cancelled_at, tochka_subscription_id, retry_count
           from subscriptions
          where user_id = $1 and tochka_subscription_id is not null
          order by created_at desc
          limit 1`,
        [user.id],
      )
      const sub = subRes.rows[0] ?? null

      const userRow = await db.queryObject<{ premium_until: Date | null; billing_email: string | null }>(
        `select premium_until, billing_email from users where id = $1`,
        [user.id],
      )
      const premiumUntil = userRow.rows[0]?.premium_until ?? null
      const billingEmail = userRow.rows[0]?.billing_email ?? null

      if (action === 'status') {
        const history = await db.queryObject<{
          amount: string
          status: string
          charge_type: string
          paid_at: Date | null
          created_at: Date
        }>(
          `select amount, status, charge_type, paid_at, created_at
             from payments
            where user_id = $1
            order by created_at desc
            limit 12`,
          [user.id],
        )
        return json(200, {
          subscription: sub && {
            status: sub.status,
            auto_renew: sub.auto_renew,
            next_billing_at: sub.next_billing_at,
            card_masked_pan: sub.card_masked_pan,
            card_type: sub.card_type,
            price_rub: sub.price_paid,
            cancelled_at: sub.cancelled_at,
          },
          premium_until: premiumUntil,
          billing_email: billingEmail,
          payments: history.rows,
        })
      }

      if (action === 'cancel') {
        if (!sub || !['active', 'past_due'].includes(sub.status)) {
          return json(409, { error: 'no_active_subscription' })
        }
        await db.queryObject(
          `update subscriptions
              set auto_renew = false, status = 'cancelled', cancelled_at = now()
            where id = $1`,
          [sub.id],
        )
        await db.queryObject(
          `insert into billing_events (subscription_id, user_id, event, detail)
           values ($1, $2, 'cancelled', $3::jsonb)`,
          [sub.id, user.id, JSON.stringify({ source: body?.source ?? 'unknown' })],
        )
        const dateStr = fmtDate(premiumUntil)
        // Onaylı metinler (§7) — sade, kart lafı yok (KARAR 4)
        await sendPush(user.id, 'Подписка отменена', `Premium активен до ${dateStr}.`)
        if (billingEmail) {
          const mail = await sendBillingEmail(billingEmail, 'cancel_confirm', { date: dateStr })
          await db.queryObject(
            `insert into billing_events (subscription_id, user_id, event, detail)
             values ($1, $2, 'notified', $3::jsonb)`,
            [sub.id, user.id, JSON.stringify({ kind: 'cancel_confirm', email_ok: mail.ok, error: mail.error ?? null })],
          )
        }
        return json(200, { cancelled: true, premium_until: premiumUntil })
      }

      if (action === 'resume') {
        if (!sub || sub.status !== 'cancelled') return json(409, { error: 'nothing_to_resume' })
        if (!premiumUntil || new Date(premiumUntil) <= new Date()) {
          // Dönem bitti: kart bağıyla ödemesiz devam yok, yeni bağlama akışı gerekir
          return json(409, { error: 'need_new_subscription' })
        }
        await db.queryObject(
          `update subscriptions
              set auto_renew = true, status = 'active', cancelled_at = null,
                  next_billing_at = $2, retry_count = 0, grace_until = null
            where id = $1`,
          [sub.id, premiumUntil],
        )
        await db.queryObject(
          `insert into billing_events (subscription_id, user_id, event, detail)
           values ($1, $2, 'reactivated', $3::jsonb)`,
          [sub.id, user.id, JSON.stringify({ source: body?.source ?? 'unknown' })],
        )
        return json(200, { resumed: true, next_billing_at: premiumUntil })
      }

      if (action === 'retry') {
        // P8 kurtarma: past_due'da kullanıcı tetikli çekim (banka S3 limiti: 20 saatte toplam <2).
        // Bildirim kapısı ARANMAZ — kullanıcının kendi başlattığı ödeme, MIT çekim değil.
        if (!sub || sub.status !== 'past_due' || !sub.tochka_subscription_id) {
          return json(409, { error: 'nothing_to_retry' })
        }
        if (await isUnknownLocked(db, sub.id)) return json(200, { ok: false, reason: 'needs_support' })
        if ((await attemptsLast20h(db, sub.id)) >= 2) return json(200, { ok: false, reason: 'retry_limit' })
        const cfgR = await db.queryObject<{ period_days: number }>(
          `select period_days from billing_config where id = 1`,
        )
        const r = await attemptCharge(db, {
          id: sub.id,
          user_id: user.id,
          tochka_subscription_id: sub.tochka_subscription_id,
          status: sub.status,
          price_paid: sub.price_paid ?? 1000,
          retry_count: sub.retry_count ?? 0,
        }, cfgR.rows[0]?.period_days ?? 30, 'user_retry')
        if (r.outcome === 'charged' || r.outcome === 'reconciled') {
          const dateStr = fmtDate(r.until ?? premiumUntil)
          await sendPush(user.id, 'SoulChoice Premium', `Подписка продлена. Premium активен до ${dateStr}.`)
          if (billingEmail) {
            await sendBillingEmail(billingEmail, 'renewal_success', { date: dateStr })
          }
          return json(200, { ok: true, premium_until: r.until })
        }
        if (r.outcome === 'fail') return json(200, { ok: false, reason: 'charge_failed' })
        return json(200, { ok: false, reason: r.outcome }) // unknown | pending_verify
      }

      return json(400, { error: 'bad_action' })
    } finally {
      await db.end()
    }
  } catch (e) {
    console.error('manage-subscription error', e)
    return json(500, { error: String(e?.message ?? e) })
  }
})
