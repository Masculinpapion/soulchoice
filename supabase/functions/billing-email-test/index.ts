// billing-email-test — 4 şablonu verilen adrese gönderir. SADECE service key ile çağrılır
// (şablon render doğrulaması için; kullanıcıya açık değildir).
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { sendBillingEmail, type BillingEmailKind } from '../_shared/billing-email.ts'

const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok')
  const auth = req.headers.get('Authorization') ?? ''
  if (!SERVICE_KEY || auth !== 'Bearer ' + SERVICE_KEY) {
    return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403 })
  }
  const body = await req.json().catch(() => ({}))
  const to = String(body?.to ?? '')
  const kinds: BillingEmailKind[] = ['renewal_reminder', 'renewal_success', 'renewal_failed', 'cancel_confirm']
  const results: Record<string, unknown> = {}
  for (const kind of kinds) {
    results[kind] = await sendBillingEmail(to, kind, { date: '07.09.2026', amount: '1 000 ₽' })
  }
  return new Response(JSON.stringify(results), { headers: { 'Content-Type': 'application/json' } })
})
