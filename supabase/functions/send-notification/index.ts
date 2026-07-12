import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''
const PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID') ?? ''
const CLIENT_EMAIL = Deno.env.get('FIREBASE_CLIENT_EMAIL') ?? ''
const PRIVATE_KEY_RAW = (Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '').replace(/\\n/g, '\n')

async function getFcmAccessToken(): Promise<string> {
  const privateKey = await jose.importPKCS8(PRIVATE_KEY_RAW, 'RS256')
  const now = Math.floor(Date.now() / 1000)
  const jwt = await new jose.SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuer(CLIENT_EMAIL)
    .setSubject(CLIENT_EMAIL)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey)
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  })
  const data = await res.json()
  return data.access_token
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  try {
    const { user_id, title, body, data } = await req.json()
    if (!user_id || !title || !body) {
      return new Response(JSON.stringify({ error: 'user_id, title, body required' }), { status: 400, headers: CORS })
    }
    const db = new Client(DB_URL)
    await db.connect()
    const result = await db.queryObject<{ fcm_token: string }>(
      'SELECT fcm_token FROM users WHERE id = $1 LIMIT 1',
      [user_id]
    )

    // Bildirim tercihleri: tür kapalıysa VEYA sessiz saatler içindeyse push
    // atlanır. Uygulama-içi notifications kaydı ayrı oluşur (bu fn sadece
    // push gönderir), o yüzden atlamak listeyi etkilemez. Kayıt yoksa
    // varsayılan: tüm push açık, sessiz saatler kapalı.
    const notifType = (data?.type as string | undefined) ?? ''
    const typeToColumn: Record<string, string> = {
      new_application: 'push_new_application',
      selected: 'push_selected',
      new_message: 'push_message',
      match: 'push_match',
    }
    const col = typeToColumn[notifType]
    if (col) {
      const prefRes = await db.queryObject<Record<string, unknown>>(
        `SELECT ${col} AS enabled, quiet_hours_enabled, quiet_hours_start, quiet_hours_end
         FROM notification_preferences WHERE user_id = $1 LIMIT 1`,
        [user_id]
      )
      const pref = prefRes.rows[0]
      if (pref) {
        // Tür kapalı → atla
        if (pref.enabled === false) {
          await db.end()
          return new Response(JSON.stringify({ success: true, skipped: 'type_disabled' }), { headers: { ...CORS, 'Content-Type': 'application/json' } })
        }
        // Sessiz saatler içinde → atla (alıcının yerel saati; sunucu Europe/Moscow)
        if (pref.quiet_hours_enabled === true && pref.quiet_hours_start && pref.quiet_hours_end) {
          const now = new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Moscow' }))
          const cur = now.getHours() * 60 + now.getMinutes()
          const [sh, sm] = String(pref.quiet_hours_start).split(':').map(Number)
          const [eh, em] = String(pref.quiet_hours_end).split(':').map(Number)
          const start = sh * 60 + sm
          const end = eh * 60 + em
          // Gece aşan aralık (örn. 22:00–08:00) da doğru değerlendirilir
          const inQuiet = start <= end ? (cur >= start && cur < end) : (cur >= start || cur < end)
          if (inQuiet) {
            await db.end()
            return new Response(JSON.stringify({ success: true, skipped: 'quiet_hours' }), { headers: { ...CORS, 'Content-Type': 'application/json' } })
          }
        }
      }
    }

    await db.end()
    const fcmToken = result.rows[0]?.fcm_token
    if (!fcmToken) {
      return new Response(JSON.stringify({ error: 'no fcm_token' }), { status: 404, headers: CORS })
    }
    const accessToken = await getFcmAccessToken()
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + accessToken,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: { title, body },
            data: data ?? {},
            android: { priority: 'high' },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      }
    )
    const fcmData = await fcmRes.json()
    return new Response(JSON.stringify({ success: true, fcm: fcmData }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500, headers: CORS })
  }
})
