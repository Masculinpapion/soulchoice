// 12.08.2026 — Nöbetçi Kovan faz 1: istemci hata toplayıcı.
// Girişsiz de çalışır (OTP/kayıt hataları en değerlileri). Alanlar kırpılır,
// istek başına 1 kayıt; kaba taşkın koruması: aynı IP'den dakikada ~30 üstü
// sessizce yutulur (alarm mekanizması checks.sh §16'da).
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
  'Content-Type': 'application/json',
}
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const bucket: Map<string, { n: number; t: number }> = new Map()

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  try {
    const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown'
    const now = Date.now()
    const b = bucket.get(ip)
    if (b && now - b.t < 60_000) {
      if (b.n >= 30) return new Response(JSON.stringify({ ok: true }), { headers: CORS })
      b.n++
    } else {
      bucket.set(ip, { n: 1, t: now })
    }

    const body = await req.json()
    const clip = (v: unknown, max: number) =>
      String(v ?? '').replace(/\s+/g, ' ').slice(0, max)

    const row = {
      user_id: typeof body.user_id === 'string' && body.user_id.length === 36 ? body.user_id : null,
      platform: clip(body.platform, 16) || 'unknown',
      app_build: clip(body.app_build, 16),
      screen: clip(body.screen, 64),
      error: clip(body.error, 600) || 'empty',
      // 03.09 (kalite teşhisi A2): stack trace (satır sonları korunur) + cihaz OS
      stack: String(body.stack ?? '').slice(0, 4000) || null,
      device: clip(body.device, 120) || null,
    }
    await fetch(SUPABASE_URL + '/rest/v1/client_errors', {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: 'Bearer ' + SERVICE_KEY,
        'Content-Type': 'application/json',
        Prefer: 'return=minimal',
      },
      body: JSON.stringify(row),
    })
    return new Response(JSON.stringify({ ok: true }), { headers: CORS })
  } catch (_) {
    // Telemetri asla istemciyi bozmaz — her durumda 200
    return new Response(JSON.stringify({ ok: true }), { headers: CORS })
  }
})
