import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
  // 31.07: CT olmadan istemci FunctionException.details'i String görüyor,
  // error kodları (too_many_attempts vb.) hiç parse edilemiyordu
  'Content-Type': 'application/json',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''

// Kullanıcı başına sabit, sunucu-sırrından türetilmiş şifre (HMAC-SHA256).
// Sır: OTP_SESSION_SECRET varsa o, yoksa service key (zaten gizli). Çıktı base64url, 43 kr.
const SESSION_SECRET = Deno.env.get('OTP_SESSION_SECRET') || SERVICE_KEY
async function derivePassword(userId: string) {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(SESSION_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode('sc-session-pass:v1:' + userId))
  return btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { phone: rawPhone, code } = await req.json()
    if (!rawPhone || !code) {
      return new Response(JSON.stringify({ error: 'phone and code required' }), { status: 400, headers: CORS })
    }
    // 03.09 (H3): send-call-otp ile aynı normalizasyon; auth.users araması iki biçimi de dener.
    const phone = String(rawPhone).replace(/[\s\-()]/g, '')
    const phoneNorm = phone.replace(/^\+/, '')

    // 03.09: doğrulama DB'de atomik (otp_verify — 20260903_otp_rpc_hardening.sql):
    // kayıt FOR UPDATE ile kilitlenir, sayaç tek UPDATE ile artar, kod sorguya
    // katılmaz (brute-force), telefon gövdede gider (kong log'una PII düşmez).
    const vRes = await fetch(SUPABASE_URL + '/rest/v1/rpc/otp_verify', {
      method: 'POST',
      headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_phone: phone, p_code: String(code) }),
    })
    if (!vRes.ok) {
      console.error('verify-call-otp RPC_FAILED ' + vRes.status)
      return new Response(JSON.stringify({ error: 'internal' }), { status: 500, headers: CORS })
    }
    const verdict = (await vRes.json()) as string
    if (verdict === 'too_many') {
      return new Response(JSON.stringify({ error: 'too_many_attempts' }), { status: 429, headers: CORS })
    }
    if (verdict !== 'ok') {
      return new Response(JSON.stringify({ error: 'invalid_code' }), { status: 401, headers: CORS })
    }

    const db = new Client(DB_URL)
    await db.connect()
    const result = await db.queryObject<{ id: string }>(
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
        // 03.09: verify hataları artık loglanır (teşhis raporu: bu fonksiyonda 0 console.error vardı).
        console.error('verify-call-otp USER_CREATE_FAILED ' + JSON.stringify(newUser).slice(0, 300))
        return new Response(JSON.stringify({ error: 'user_create_failed' }), { status: 500, headers: CORS })
      }
      userId = newUser.id
    }

    // 19.08.2026 — ÇOKLU CİHAZ FİX: eskiden her girişte rastgele geçici şifre
    // yazılıyordu (admin PUT password) → GoTrue şifre değişince kullanıcının
    // DİĞER TÜM oturumlarını düşürüyordu: web'den giriş telefonu, ikinci cihaz
    // birinciyi sessizce çıkarıyordu (17.08 "Invalid Refresh Token" kayıtları,
    // 19.08 üyelik ekranı 401). Artık kullanıcı başına sunucu sırrından
    // TÜRETİLMİŞ SABİT şifre: önce onunla oturum aç; olmazsa (ilk giriş /
    // eski rastgele şifre) BİR KEZ yaz ve tekrar dene. Şifre sunucudan çıkmaz,
    // OTP kapısı değişmez; sonraki girişler şifreye dokunmaz → oturumlar yaşar.
    const derivedPass = await derivePassword(userId)
    const grant = async (pass: string) => {
      for (const p of [phone, phoneNorm]) {
        const tokenRes = await fetch(SUPABASE_URL + '/auth/v1/token?grant_type=password', {
          method: 'POST',
          headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ phone: p, password: pass }),
        })
        const js: any = await tokenRes.json()
        if (js.access_token) return js
      }
      return {}
    }

    let session: any = await grant(derivedPass)
    if (!session.access_token) {
      // Şifre henüz türetilmiş değil (ilk giriş / eski akıştan kalan rastgele şifre):
      // son kez yaz. Bu tek seferlik yazma eski oturumları düşürür; sonrakiler düşürmez.
      await fetch(SUPABASE_URL + '/auth/v1/admin/users/' + userId, {
        method: 'PUT',
        headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: derivedPass, phone_confirm: true }),
      })
      session = await grant(derivedPass)
    }

    if (!session.access_token) {
      console.error('verify-call-otp SESSION_FAILED ' + JSON.stringify(session).slice(0, 300))
      return new Response(JSON.stringify({ error: 'session_failed' }), { status: 500, headers: CORS })
    }

    return new Response(JSON.stringify(
session), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e: any) {
    console.error('verify-call-otp ERROR ' + String((e as Error).message).slice(0, 300))
    return new Response(JSON.stringify({ error: 'internal' }), { status: 500, headers: CORS })
  }
})
