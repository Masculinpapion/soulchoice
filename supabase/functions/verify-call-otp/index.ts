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
    const { phone, code } = await req.json()
    if (!phone || !code) {
      return new Response(JSON.stringify({ error: 'phone and code required' }), { status: 400, headers: CORS })
    }

    const phoneNorm = phone.replace(/^\+/, '')
    const MAX_ATTEMPTS = 5

    const now = new Date().toISOString()
    // Brute-force koruması: kodu SORGUYA katma; önce telefonun geçerli OTP
    // kaydını çek, deneme sayısını kontrol et, sonra kodu KODDA karşılaştır.
    const otpRes = await fetch(
      SUPABASE_URL + '/rest/v1/call_otps?phone=eq.' + encodeURIComponent(phone) + '&expires_at=gt.' + now + '&order=created_at.desc&limit=1',
      { headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY } }
    )
    const otpRows = await otpRes.json()
    if (!Array.isArray(otpRows) || otpRows.length === 0) {
      return new Response(JSON.stringify({ error: 'invalid_code' }), { status: 401, headers: CORS })
    }
    const otp = otpRows[0]

    // 5 yanlış denemeden sonra kod iptal — yeni kod istemek zorunlu
    if ((otp.attempts ?? 0) >= MAX_ATTEMPTS) {
      await fetch(SUPABASE_URL + '/rest/v1/call_otps?phone=eq.' + encodeURIComponent(phone), {
        method: 'DELETE',
        headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY },
      })
      return new Response(JSON.stringify({ error: 'too_many_attempts' }), { status: 429, headers: CORS })
    }

    // Kod yanlış → deneme sayacını artır, kaydı SİLME (kullanıcı tekrar denesin)
    if (String(otp.code) !== String(code)) {
      await fetch(SUPABASE_URL + '/rest/v1/call_otps?id=eq.' + otp.id, {
        method: 'PATCH',
        headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
        body: JSON.stringify({ attempts: (otp.attempts ?? 0) + 1 }),
      })
      return new Response(JSON.stringify({ error: 'invalid_code' }), { status: 401, headers: CORS })
    }

    // Kod doğru → tüm OTP kayıtlarını sil (mevcut akış)
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
