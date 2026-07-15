import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

const TOCHKA_API = 'https://enter.tochka.com/uapi'
const TOCHKA_JWT = Deno.env.get('TOCHKA_JWT_TOKEN') ?? ''
const CUSTOMER_CODE = Deno.env.get('TOCHKA_CUSTOMER_CODE') ?? '305892846'
const MERCHANT_ID = Deno.env.get('TOCHKA_MERCHANT_ID') ?? '200000000040619'
// Banka test protokolü (1-2₽) için: sadece TEST_PAYMENT_KEY eşleşirse tutar override edilir
const TEST_PAYMENT_KEY = Deno.env.get('TEST_PAYMENT_KEY') ?? ''

const PRICE_RUB = 1000
const VALID_SOURCES = ['web', 'android', 'ios_app']

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    if (!TOCHKA_JWT) {
      return new Response(JSON.stringify({ error: 'tochka_not_configured' }), { status: 500, headers: CORS })
    }

    // Çağıran kullanıcıyı kendi JWT'sinden doğrula
    const authHeader = req.headers.get('Authorization') ?? ''
    const userRes = await fetch(SUPABASE_URL + '/auth/v1/user', {
      headers: { apikey: ANON_KEY, Authorization: authHeader },
    })
    if (!userRes.ok) {
      return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401, headers: CORS })
    }
    const user = await userRes.json()
    if (!user?.id) {
      return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401, headers: CORS })
    }

    const body = await req.json().catch(() => ({}))
    const source = VALID_SOURCES.includes(body?.source) ? body.source : 'web'

    let amount = PRICE_RUB
    let isTest = false
    if (body?.testAmount != null) {
      if (!TEST_PAYMENT_KEY || body?.testKey !== TEST_PAYMENT_KEY) {
        return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403, headers: CORS })
      }
      amount = Number(body.testAmount)
      isTest = true
      if (!Number.isFinite(amount) || amount < 1 || amount > 100) {
        return new Response(JSON.stringify({ error: 'bad_test_amount' }), { status: 400, headers: CORS })
      }
    }

    const purpose = isTest
      ? 'Тест интеграции SoulChoice Premium'
      : 'Подписка SoulChoice Premium, 1 месяц'

    // Birikme önle (Mustafa kuralı): bir kullanıcının aynı anda EN FAZLA BİR açık
    // pending one_time order'ı olsun. Ödemeyi yarıda bırakıp tekrar denerse yeni
    // order açma — mevcut açık (7 gün içi, Точка order ömrü) order'ı ve aynı ödeme
    // linkini yeniden kullan. Yeni order yalnız: eski ödendi/expired/iptal edildi.
    // (subscription akışı zaten reuse yapıyor; bu one_time için aynı kuralı getirir.)
    if (!isTest) {
      const exRes = await fetch(
        SUPABASE_URL + '/rest/v1/payments?user_id=eq.' + user.id +
          '&status=eq.pending&charge_type=eq.one_time' +
          '&select=payment_link,operation_id,created_at&order=created_at.desc&limit=1',
        { headers: { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY } },
      )
      const ex = await exRes.json().catch(() => [])
      const cur = Array.isArray(ex) ? ex[0] : null
      if (
        cur?.payment_link &&
        Date.now() - new Date(cur.created_at).getTime() < 7 * 24 * 3600 * 1000
      ) {
        return new Response(
          JSON.stringify({ paymentLink: cur.payment_link, operationId: cur.operation_id, reused: true }),
          { headers: { ...CORS, 'Content-Type': 'application/json' } },
        )
      }
    }

    const tochkaRes = await fetch(TOCHKA_API + '/acquiring/v1.0/payments', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + TOCHKA_JWT, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        Data: {
          customerCode: CUSTOMER_CODE,
          merchantId: MERCHANT_ID,
          amount: amount.toFixed(2),
          purpose,
          paymentMode: ['sbp', 'card'],
          redirectUrl: 'https://soulchoice.app/?payment=success',
          failRedirectUrl: 'https://soulchoice.app/?payment=fail',
        },
      }),
    })
    const tochkaJson = await tochkaRes.json()
    const op = tochkaJson?.Data
    if (!tochkaRes.ok || !op?.operationId || !op?.paymentLink) {
      console.error('tochka create payment failed', JSON.stringify(tochkaJson))
      return new Response(JSON.stringify({ error: 'payment_create_failed' }), { status: 502, headers: CORS })
    }

    const insertRes = await fetch(SUPABASE_URL + '/rest/v1/payments', {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: 'Bearer ' + SERVICE_KEY,
        'Content-Type': 'application/json',
        Prefer: 'return=minimal',
      },
      body: JSON.stringify({
        user_id: user.id,
        operation_id: op.operationId,
        amount,
        currency: 'RUB',
        source: isTest ? 'test' : source,
        status: 'pending',
        purpose,
        payment_link: op.paymentLink,
        charge_type: 'one_time',
      }),
    })
    if (!insertRes.ok) {
      // Link üretildi ama kayıt düşmedi: webhook tarafı operation_id ile telafi eder
      console.error('payments insert failed', await insertRes.text())
    }

    return new Response(
      JSON.stringify({ paymentLink: op.paymentLink, operationId: op.operationId }),
      { headers: { ...CORS, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('create-tochka-payment error', e)
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: CORS })
  }
})
