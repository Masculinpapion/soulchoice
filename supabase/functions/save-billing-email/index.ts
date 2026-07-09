// save-billing-email — Seçenek B (09.07.2026): onboarding'den opsiyonel e-posta + pazarlama rızası.
// E-postayı users.billing_email'e yazar, rızayı billing_events'e loglar (ФЗ-38 kanıtı),
// e-posta İLK KEZ kaydediliyorsa D+0 hoş geldin mailini anında yollar.
// D+2 premium tanıtımı billing-cron lifecycle fazında (limit-anı tetiklemesi YOK — D+2 ilkesi).
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'
import { sendBillingEmail } from '../_shared/billing-email.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''

const CONSENT_TEXT_VERSION = '2026-07-09'
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
    const authHeader = req.headers.get('Authorization') ?? ''
    const userRes = await fetch(SUPABASE_URL + '/auth/v1/user', {
      headers: { apikey: ANON_KEY, Authorization: authHeader },
    })
    if (!userRes.ok) return json(401, { error: 'unauthorized' })
    const user = await userRes.json()
    if (!user?.id) return json(401, { error: 'unauthorized' })

    const body = await req.json().catch(() => ({}))
    const email = String(body?.email ?? '').trim().toLowerCase()
    const marketingConsent = body?.marketing_consent === true
    const source = typeof body?.source === 'string' ? body.source.slice(0, 40) : 'unknown'
    if (!EMAIL_RE.test(email)) return json(400, { error: 'bad_email' })

    const db = new Client(DB_URL)
    await db.connect()
    try {
      const prev = await db.queryObject<{ billing_email: string | null }>(
        `select billing_email from users where id = $1`,
        [user.id],
      )
      if (prev.rows.length === 0) return json(409, { error: 'no_profile' })
      const prevEmail = prev.rows[0].billing_email

      await db.queryObject(
        `update users set billing_email = $2 where id = $1`,
        [user.id, email],
      )

      if (marketingConsent) {
        await db.queryObject(
          `insert into billing_events (user_id, event, detail)
           values ($1, 'marketing_consent', $2::jsonb)`,
          [user.id, JSON.stringify({
            channels: ['email'],
            text_version: CONSENT_TEXT_VERSION,
            accepted_at: new Date().toISOString(),
            source,
            email,
          })],
        )
      }

      // Hoş geldin yalnız İLK kayıtta — profil düzenlemede tekrar gönderilmez
      let welcomeSent = false
      if (!prevEmail || prevEmail.toLowerCase() !== email) {
        const already = await db.queryObject(
          `select 1 from billing_events where user_id = $1 and event = 'welcome_sent' limit 1`,
          [user.id],
        )
        if (already.rows.length === 0) {
          const mail = await sendBillingEmail(email, 'welcome')
          welcomeSent = mail.ok
          await db.queryObject(
            `insert into billing_events (user_id, event, detail)
             values ($1, 'welcome_sent', $2::jsonb)`,
            [user.id, JSON.stringify({ ok: mail.ok, error: mail.error ?? null, email })],
          )
        }
      }

      return json(200, { ok: true, welcome_sent: welcomeSent })
    } finally {
      await db.end()
    }
  } catch (e) {
    console.error('save-billing-email error', e)
    return json(500, { error: String(e?.message ?? e) })
  }
})
