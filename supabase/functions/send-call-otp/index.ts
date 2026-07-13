import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const SMS_RU_API_KEY = Deno.env.get('SMS_RU_API_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const TEST_PHONE = '+79295774238'
const TEST_CODE = '1234'
// Test bypass yalnızca ALLOW_TEST_OTP=true ortamında (dev) çalışır. Production
// edge function ortamında bu değişken TANIMSIZ olduğundan bypass asla açılmaz —
// gerçek SMS.ru call-OTP akışı devreye girer. Dev'de test için env'e ekle.
const ALLOW_TEST_OTP = Deno.env.get('ALLOW_TEST_OTP') === 'true'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { phone } = await req.json()
    if (!phone) return new Response(JSON.stringify({ error: 'phone required' }), { status: 400, headers: CORS })

    // SMS bombing koruması: aynı numaraya 60 sn içinde yeni kod YOK. Kontrol
    // SMS.ru çağrısından ÖNCE — hem bakiyeyi hem kurbanı (art arda çağrı) korur.
    // Test bypass muaf (dev). App'te zaten 60 sn resend timer var; backend zorlar.
    const isTestBypass = ALLOW_TEST_OTP && phone === TEST_PHONE
    if (!isTestBypass) {
      const lastRes = await fetch(
        SUPABASE_URL + '/rest/v1/call_otps?phone=eq.' + encodeURIComponent(phone) + '&select=created_at&order=created_at.desc&limit=1',
        { headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY } }
      )
      const last = await lastRes.json()
      if (Array.isArray(last) && last[0]) {
        const ageMs = Date.now() - new Date(last[0].created_at).getTime()
        if (ageMs < 60_000) {
          return new Response(
            JSON.stringify({ error: 'too_soon', retry_after: Math.ceil((60_000 - ageMs) / 1000) }),
            { status: 429, headers: CORS }
          )
        }
      }
    }

    let code: string

    if (ALLOW_TEST_OTP && phone === TEST_PHONE) {
      code = TEST_CODE
    } else {
      const url = 'https://sms.ru/code/call?phone=' + encodeURIComponent(phone) + '&api_id=' + SMS_RU_API_KEY + '&json=1'
      const res = await fetch(url)
      const data = await res.json()
      if (data.status !== 'OK') {
        return new Response(JSON.stringify({ error: 'call_failed', detail: data }), { status: 500, headers: CORS })
      }
      code = data.code
    }

    await fetch(SUPABASE_URL + '/rest/v1/call_otps?phone=eq.' + encodeURIComponent(phone), {
      method: 'DELETE',
      headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY },
    })

    await fetch(SUPABASE_URL + '/rest/v1/call_otps', {
      method: 'POST',
      headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone, code, expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString() }),
    })

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500, headers: CORS })
  }
})
