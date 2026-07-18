import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const SMS_RU_API_KEY = Deno.env.get('SMS_RU_API_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
// Test/demo bypass yalnızca ALLOW_TEST_OTP=true iken çalışır.
// KURAL: Bu listeye SADECE gerçekte tahsis edilemeyen +7000-blok numaraları
// girer; gerçek (aranabilir) numara ASLA eklenmez. Flag, store-review demo
// girişi için prod'da AÇIK durur — gerçek numara bypass'ı hesap ele geçirme
// kapısı olurdu (+79295774238 bypass'ı bu gerekçeyle 15.07.2026'da kaldırıldı).
// Demo hesabı ve inceleme talimatı: docs/store-review-demo.md
const TEST_PHONES: Record<string, string> = {
  '+70000000001': '1234', // store-review / demo hesabı
}
const ALLOW_TEST_OTP = Deno.env.get('ALLOW_TEST_OTP') === 'true'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { phone, channel } = await req.json()
    if (!phone) return new Response(JSON.stringify({ error: 'phone required' }), { status: 400, headers: CORS })
    // Kanal seçimi: yeni app sürümleri channel:'sms' gönderir (birincil kanal).
    // Parametresiz istekler = SAHADAKİ ESKİ BUILD'LER → çağrı (UI'ları çağrıya
    // göre yazılmış; varsayılanı sms yapmak sürüm çakışması yaratır).
    const useSms = channel === 'sms'

    // SMS bombing koruması: aynı numaraya 60 sn içinde yeni kod YOK. Kontrol
    // SMS.ru çağrısından ÖNCE — hem bakiyeyi hem kurbanı (art arda çağrı) korur.
    // Test bypass muaf (dev). App'te zaten 60 sn resend timer var; backend zorlar.
    const testCode = ALLOW_TEST_OTP ? TEST_PHONES[phone] : undefined
    const isTestBypass = testCode !== undefined
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

    if (isTestBypass) {
      code = testCode!
    } else if (useSms) {
      // Kodu biz üretiriz; gönderici adı SMS.ru panelinde varsayılan "SoulChoice"
      // (operatörde ad onaylanana kadar SMS.ru stok adla teslim eder, geçiş otomatik).
      const buf = new Uint32Array(1)
      crypto.getRandomValues(buf)
      code = String(1000 + (buf[0] % 9000))
      const url = 'https://sms.ru/sms/send?api_id=' + SMS_RU_API_KEY +
        '&to=' + encodeURIComponent(phone) +
        '&msg=' + encodeURIComponent('SoulChoice: код подтверждения ' + code) + '&json=1'
      const res = await fetch(url)
      const data = await res.json()
      const smsInfo = data.sms ? (Object.values(data.sms)[0] as { status?: string } | undefined) : undefined
      if (data.status !== 'OK' || smsInfo?.status !== 'OK') {
        return new Response(JSON.stringify({ error: 'sms_failed', detail: data }), { status: 500, headers: CORS })
      }
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
