import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const SMS_RU_API_KEY = Deno.env.get('SMS_RU_API_KEY') ?? ''

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, content-type',
      },
    })
  }

  try {
    const { phone } = await req.json()
    if (!phone) {
      return new Response(JSON.stringify({ error: 'phone required' }), { status: 400 })
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString()

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    await fetch(supabaseUrl + '/rest/v1/otp_codes', {
      method: 'POST',
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer ' + supabaseKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        phone: phone,
        code: otp,
        expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
      }),
    })

    const smsUrl = 'https://sms.ru/sms/send?api_id=' + SMS_RU_API_KEY + '&to=' + phone + '&msg=SoulChoice+kод:+' + otp + '&json=1'
    const smsRes = await fetch(smsUrl)
    const smsData = await smsRes.json()

    if (smsData.status !== 'OK') {
      return new Response(JSON.stringify({ error: 'sms_failed', detail: smsData }), { status: 500 })
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
