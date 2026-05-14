import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

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
    const { phone, code } = await req.json()
    if (!phone || !code) {
      return new Response(JSON.stringify({ error: 'phone and code required' }), { status: 400 })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const res = await fetch(
      supabaseUrl + '/rest/v1/otp_codes?phone=eq.' + encodeURIComponent(phone) + '&code=eq.' + code + '&order=created_at.desc&limit=1',
      {
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer ' + supabaseKey,
        },
      }
    )
    const rows = await res.json()

    if (!rows.length) {
      return new Response(JSON.stringify({ error: 'invalid_code' }), { status: 401 })
    }

    const row = rows[0]
    if (new Date(row.expires_at) < new Date()) {
      return new Response(JSON.stringify({ error: 'code_expired' }), { status: 401 })
    }

    await fetch(supabaseUrl + '/rest/v1/otp_codes?id=eq.' + row.id, {
      method: 'DELETE',
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer ' + supabaseKey,
      },
    })

    const tokenRes = await fetch(supabaseUrl + '/auth/v1/otp', {
      method: 'POST',
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer ' + supabaseKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ phone: phone, create_user: true }),
    })

    return new Response(JSON.stringify({ success: true, verified: true }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
