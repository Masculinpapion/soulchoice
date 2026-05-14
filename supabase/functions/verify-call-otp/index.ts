import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { phone, code } = await req.json()
    if (!phone || !code) {
      return new Response(JSON.stringify({ error: 'phone and code required' }), { status: 400, headers: CORS })
    }

    const phoneNorm = phone.replace(/^\+/, '')

    const now = new Date().toISOString()
    const checkRes = await fetch(
      SUPABASE_URL + '/rest/v1/call_otps?phone=eq.' + encodeURIComponent(phone) + '&code=eq.' + encodeURIComponent(code) + '&expires_at=gt.' + now + '&limit=1',
      { headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY } }
    )
    const rows = await checkRes.json()
    if (!Array.isArray(rows) || rows.length === 0) {
      return new Response(JSON.stringify({ error: 'invalid_code' }), { status: 401, headers: CORS })
    }

    await fetch(SUPABASE_URL + '/rest/v1/call_otps?phone=eq.' + encodeURIComponent(phone), {
      method: 'DELETE',
      headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY },
    })

    const db = new Client(DB_URL)
    await db.connect()
    const result = await db.queryObject(
      'SELECT id FROM auth.users WHERE phone = $1 OR phone = $2 LIMIT 1',
      [phone, phoneNorm]
    )
    await db.end()

    let userId
    if (result.rows.length > 0) {
      userId = result.rows[0].id
    } else {
      const createRes = await fetch(SUPABASE_URL + '/auth/v1/admin/users', {
        method: 'POST',
        headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, phone_confirm: true }),
      })
      const newUser = await createRes.json()
      if (!newUser.id) {
        return new Response(JSON.stringify({ error: 'user_create_failed', detail: newUser }), { status: 500, headers: CORS })
      }
      userId = newUser.id
    }

    const tempPass = crypto.randomUUID()
    await fetch(SUPABASE_URL + '/auth/v1/admin/users/' + userId, {
      method: 'PUT',
      headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: tempPass, phone_confirm: true }),
    })

    let session = {}
    for (const p of [phone, phoneNorm]) {
      const tokenRes = await fetch(SUPABASE_URL + '/auth/v1/token?grant_type=password', {
        method: 'POST',
        headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: p, password: tempPass }),
      })
      session = await tokenRes.json()
      if (session.access_token) break
    }

    if (!session.access_token) {
      return new Response(JSON.stringify({ error: 'session_failed', detail: session }), { status: 500, headers: CORS })
    }

    return new Response(JSON.stringify(
session), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS })
  }
})
