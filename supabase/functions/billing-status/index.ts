// billing-status — P3 dead-man switch okuma ucu. Sır İÇERMEZ; harici uptime servisi
// last_run_age_seconds > 93600 (26 saat) olduğunda alarm verir.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok')
  const db = new Client(DB_URL)
  try {
    await db.connect()
    const res = await db.queryObject<{ last_run_at: Date; last_status: string }>(
      `select last_run_at, last_status from cron_heartbeat where job = 'billing-cron'`,
    )
    const row = res.rows[0]
    const body = row
      ? {
        last_run_age_seconds: Math.floor((Date.now() - new Date(row.last_run_at).getTime()) / 1000),
        last_status: row.last_status,
      }
      : { last_run_age_seconds: null, last_status: 'never_ran' }
    return new Response(JSON.stringify(body), { headers: { 'Content-Type': 'application/json' } })
  } catch (e) {
    return new Response(JSON.stringify({ error: 'unavailable' }), { status: 500 })
  } finally {
    try {
      await db.end()
    } catch (_) { /* bağlantı zaten kapalı */ }
  }
})
