import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
  // 31.07: CT olmadan istemci hata kodlarını (too_soon/retry_after) parse edemiyordu
  'Content-Type': 'application/json',
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
// Aynı liste DB'de otp_is_bypass() içinde (tavan muafiyeti) — ikisi birlikte güncellenir.
const TEST_PHONES: Record<string, string> = {
  '+70000000001': '1234', // store-review / demo hesabı
  '+70000000002': '1234', // Play kapalı test — TR testçi (Rıdvan), 26.08.2026
  '+70000000003': '1234', // Play kapalı test — TR testçi (Sezer), 26.08.2026
  '+70000000004': '1234', // Play kapalı test — TR testçi (salcandyni), 29.08.2026
  '+70000000005': '1234', // Play kapalı test — TR testçi #5, 29.08.2026
  '+70000000006': '1234', // Play kapalı test — TR testçi #6, 29.08.2026
  '+70000000007': '1234', // Play kapalı test — TR testçi #7, 29.08.2026
}
const ALLOW_TEST_OTP = Deno.env.get('ALLOW_TEST_OTP') === 'true'

// 03.09: OTP durum mantığı DB RPC'lerinde (20260903_otp_rpc_hardening.sql).
// Telefon gövdede gider → kong access log'una numara düşmez (PII).
async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const res = await fetch(SUPABASE_URL + '/rest/v1/rpc/' + fn, {
    method: 'POST',
    headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify(args),
  })
  if (!res.ok) throw new Error('rpc_' + fn + '_' + res.status)
  return (await res.json()) as T
}

// Log/alarm satırlarında telefon numarası maskelenir (Telegram'a taşınıyor).
function maskPhones(s: string): string {
  return s.replace(/7\d{6}(\d{4})/g, '7******$1')
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { phone: rawPhone, channel, app_signature } = await req.json()
    if (!rawPhone) return new Response(JSON.stringify({ error: 'phone required' }), { status: 400, headers: CORS })
    // 11.08: kayıt yalnız +7 (ürün kuralı; istemci zaten yalnız +7 üretir).
    // 03.09 (H3): normalize edilmiş numara HER yerde kullanılır — throttle, SMS, saklama.
    const phone = String(rawPhone).replace(/[\s\-()]/g, '')
    if (!/^\+7\d{10}$/.test(phone)) {
      return new Response(JSON.stringify({ error: 'unsupported_region' }), { status: 400, headers: CORS })
    }
    // Android SMS Retriever hash'i: istemci kendi imza hash'ini gönderir (Play/
    // RuStore/debug sertifikaları farklı → hash sabitlenemez). Sıkı format
    // kontrolü, SMS metnine serbest string enjeksiyonunu engeller.
    const appHash =
      typeof app_signature === 'string' && /^[A-Za-z0-9+/]{11}$/.test(app_signature)
        ? app_signature
        : null
    // Kanal seçimi: yeni app sürümleri channel:'sms' gönderir (birincil kanal).
    // Parametresiz istekler = SAHADAKİ ESKİ BUILD'LER → çağrı (UI'ları çağrıya
    // göre yazılmış; varsayılanı sms yapmak sürüm çakışması yaratır).
    const useSms = channel === 'sms'
    const channelName = useSms ? 'sms' : 'call'

    const testCode = ALLOW_TEST_OTP ? TEST_PHONES[phone] : undefined
    const isTestBypass = testCode !== undefined

    // SMS bombing + günlük tavan: SMS.ru çağrısından ÖNCE (H4). Bypass DB'de de muaf.
    if (!isTestBypass) {
      const pre = await rpc<string>('otp_precheck', { p_phone: phone })
      if (pre.startsWith('too_soon')) {
        const retry = Number(pre.split(':')[1] || 60)
        return new Response(JSON.stringify({ error: 'too_soon', retry_after: retry }), { status: 429, headers: CORS })
      }
      if (pre === 'cap') {
        console.error('send-call-otp OTP_CAP ' + maskPhones(phone))
        return new Response(JSON.stringify({ error: 'otp_cap_reached' }), { status: 429, headers: CORS })
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
      // Hash SMS'in SON satırına eklenir (Retriever şartı); hash'siz istemciler
      // eski metni aynen alır.
      const smsText = 'SoulChoice: код подтверждения ' + code +
        (appHash ? '\n' + appHash : '')
      const url = 'https://sms.ru/sms/send?api_id=' + SMS_RU_API_KEY +
        '&to=' + encodeURIComponent(phone) +
        '&msg=' + encodeURIComponent(smsText) + '&json=1'
      const res = await fetch(url)
      const data = await res.json()
      const smsInfo = data.sms ? (Object.values(data.sms)[0] as { status?: string; status_code?: number; status_text?: string } | undefined) : undefined
      if (data.status !== 'OK' || smsInfo?.status !== 'OK') {
        // 11.08: ret SEBEBİ loglanır — 19:38-19:58 vakasında 12 ardışık ret
        // yaşandı ama sebep görünmüyordu (SMS.ru limit mi, rota mı, bakiye mi).
        // 03.09: sms.ru cevabı numarayı anahtar olarak taşır → maskelenir (Telegram'a gidiyor).
        const reason = String(smsInfo?.status_code ?? data.status_code ?? '?')
        console.error('send-call-otp SMS_FAILED ' + maskPhones(JSON.stringify(data)))
        await rpc('otp_log_fail', { p_phone: phone, p_channel: 'sms', p_reason: reason }).catch(() => {})
        return new Response(JSON.stringify({ error: 'sms_failed', code: reason }), { status: 500, headers: CORS })
      }
    } else {
      const url = 'https://sms.ru/code/call?phone=' + encodeURIComponent(phone) + '&api_id=' + SMS_RU_API_KEY + '&json=1'
      const res = await fetch(url)
      const data = await res.json()
      if (data.status !== 'OK') {
        const reason = String(data.status_code ?? '?')
        console.error('send-call-otp CALL_FAILED ' + maskPhones(JSON.stringify(data)))
        await rpc('otp_log_fail', { p_phone: phone, p_channel: 'call', p_reason: reason }).catch(() => {})
        return new Response(JSON.stringify({ error: 'call_failed', code: reason }), { status: 500, headers: CORS })
      }
      code = data.code
    }

    const stored = await rpc<string>('otp_store', { p_phone: phone, p_code: code, p_channel: channelName })
    if (stored !== 'ok') {
      // Yarış: precheck ile store arasında tavan dolduysa. Kod saklanmadı; kullanıcıya dürüst cevap.
      console.error('send-call-otp STORE_' + stored.toUpperCase() + ' ' + maskPhones(phone))
      return new Response(JSON.stringify({ error: 'otp_cap_reached' }), { status: 429, headers: CORS })
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('send-call-otp ERROR ' + maskPhones((e as Error).message))
    return new Response(JSON.stringify({ error: 'internal' }), { status: 500, headers: CORS })
  }
})
