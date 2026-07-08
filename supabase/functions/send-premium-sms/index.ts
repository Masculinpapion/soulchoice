import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

// iOS Premium SMS akışı ("kargo bildirimi" deseni):
// Ücretsiz başvurusunu kullanan iOS kullanıcısına, uygulama DIŞINDAN (SMS)
// kişisel Точка ödeme linki gönderilir. Uygulamada sıfır piksel — App Store
// guideline 3.1.3 uygulama dışı iletişimi serbest bırakır.
// Tetikleyici: pg_cron + pg_net (5 dk'da bir), auth = service role key.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const SMS_RU_API_KEY = Deno.env.get('SMS_RU_API_KEY') ?? ''

const TOCHKA_API = 'https://enter.tochka.com/uapi'
const TOCHKA_JWT = Deno.env.get('TOCHKA_JWT_TOKEN') ?? ''
const CUSTOMER_CODE = Deno.env.get('TOCHKA_CUSTOMER_CODE') ?? '305892846'
const MERCHANT_ID = Deno.env.get('TOCHKA_MERCHANT_ID') ?? '200000000040619'

const PRICE_RUB = 1000
const PURPOSE = 'Подписка SoulChoice Premium, 1 месяц'
// Onaylı metin (Variant A, 08.07.2026) — «заявка» terimi paywall ile aynı
const SMS_TEXT = (link: string) =>
  'SoulChoice: бесплатная заявка использована. Продолжить знакомства — ' +
  'Premium 1000 ₽/мес, оплата в 1 клик: ' + link

const rest = (path: string, init: RequestInit = {}) =>
  fetch(SUPABASE_URL + '/rest/v1' + path, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: 'Bearer ' + SERVICE_KEY,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  })

serve(async (req) => {
  // Sadece cron çağırır: service role key şartı (route Kong'da açık)
  const auth = req.headers.get('Authorization') ?? ''
  if (!SERVICE_KEY || auth !== 'Bearer ' + SERVICE_KEY) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 })
  }
  if (!TOCHKA_JWT || !SMS_RU_API_KEY) {
    return new Response(JSON.stringify({ error: 'not_configured' }), { status: 500 })
  }

  try {
    // Uygun kitle: ücretsiz hakkını kullanmış, free, iOS, daha önce SMS almamış.
    // Şimdilik sadece RU dilli kullanıcılar (EN SMS metni henüz onaylanmadı).
    const usersRes = await rest(
      '/users?select=id,phone' +
        '&free_application_used=eq.true' +
        '&subscription_status=eq.free' +
        '&last_platform=eq.ios' +
        '&premium_sms_sent_at=is.null' +
        '&language=eq.ru' +
        '&banned=eq.false&is_deleted=eq.false&phone=not.is.null' +
        '&limit=20',
    )
    if (!usersRes.ok) throw new Error('users query failed: ' + (await usersRes.text()))
    const users: { id: string; phone: string }[] = await usersRes.json()

    const results: Record<string, string> = {}
    for (const u of users) {
      // Kişisel ödeme linki (7 gün geçerli, hesaba payments kaydıyla bağlı)
      const tochkaRes = await fetch(TOCHKA_API + '/acquiring/v1.0/payments', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + TOCHKA_JWT, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          Data: {
            customerCode: CUSTOMER_CODE,
            merchantId: MERCHANT_ID,
            amount: PRICE_RUB.toFixed(2),
            purpose: PURPOSE,
            paymentMode: ['sbp', 'card'],
            redirectUrl: 'https://soulchoice.app/?payment=success',
            failRedirectUrl: 'https://soulchoice.app/?payment=fail',
          },
        }),
      })
      const tochkaJson = await tochkaRes.json()
      const op = tochkaJson?.Data
      if (!tochkaRes.ok || !op?.operationId || !op?.paymentLink) {
        console.error('tochka create failed for', u.id, JSON.stringify(tochkaJson))
        results[u.id] = 'tochka_failed'
        continue // link yoksa SMS de damga da yok — sonraki turda tekrar denenir
      }

      const insertRes = await rest('/payments', {
        method: 'POST',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({
          user_id: u.id,
          operation_id: op.operationId,
          amount: PRICE_RUB,
          currency: 'RUB',
          source: 'ios_sms', // Apple raporuna GİRMEZ (uygulama dışı kanal, %0)
          status: 'pending',
          purpose: PURPOSE,
          payment_link: op.paymentLink,
        }),
      })
      if (!insertRes.ok) console.error('payments insert failed', await insertRes.text())

      // Dedupe garantisi: göndermeden ÖNCE damgala (tek SMS kuralı) —
      // teslimat hatası spam'e değil log'a düşer, elle takip edilir.
      const stampRes = await rest('/users?id=eq.' + u.id, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({ premium_sms_sent_at: new Date().toISOString() }),
      })
      if (!stampRes.ok) {
        console.error('stamp failed for', u.id, await stampRes.text())
        results[u.id] = 'stamp_failed'
        continue // damga başarısızsa SMS atma — çift gönderim riski
      }

      const smsRes = await fetch('https://sms.ru/sms/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          api_id: SMS_RU_API_KEY,
          to: u.phone,
          msg: SMS_TEXT(op.paymentLink),
          json: '1',
        }),
      })
      const smsJson = await smsRes.json().catch(() => null)
      const smsStatus = smsJson?.sms?.[u.phone]
      if (smsJson?.status === 'OK' && smsStatus?.status === 'OK') {
        console.log('premium sms sent', u.id, 'sms_id', smsStatus?.sms_id)
        results[u.id] = 'sent:' + (smsStatus?.sms_id ?? '?')
      } else {
        console.error('sms send failed', u.id, JSON.stringify(smsJson))
        results[u.id] = 'sms_failed'
      }
    }

    return new Response(JSON.stringify({ candidates: users.length, results }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('send-premium-sms error', e)
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
