// selection-reminder — saatlik (host crontab): seçim penceresi ≤12 saat kalan,
// bekleyen başvurusu olan ve henüz hatırlatılmamış ilan sahiplerine
// in-app bildirim + push gönderir (🟡5, 15.07 yolculuk taraması).
// Push metni send-notification şablonundan ALICININ dilinde üretilir;
// bildirim tercihi/sessiz saatler de orada uygulanır.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

serve(async (_req) => {
  const db = new Client(DB_URL)
  await db.connect()
  const reminded: string[] = []
  try {
    const cands = await db.queryObject<{ id: string; owner_id: string; cnt: bigint }>(`
      select i.id, i.owner_id, count(a.id) as cnt
        from invitations i
        join applications a on a.invitation_id = i.id and a.status = 'pending'
       where i.status = 'selecting'
         and i.selection_deadline > now()
         and i.selection_deadline <= now() + interval '12 hours'
         and i.owner_reminded_at is null
       group by i.id, i.owner_id`)

    for (const c of cands.rows) {
      const count = Number(c.cnt)
      // Önce işaretle — push başarısız olsa da aynı ilana ikinci kez üşüşmeyiz
      await db.queryObject(
        `update invitations set owner_reminded_at = now() where id = $1`,
        [c.id],
      )
      // In-app kaydı (ekran type'a göre render-time lokalize eder; RU fallback)
      await db.queryObject(
        `insert into notifications (user_id, type, title, body, payload)
         values ($1, 'selection_reminder', 'Заявки ждут ✨',
                 'Окно выбора скоро закроется — взгляните на заявки.',
                 jsonb_build_object('invitation_id', $2))`,
        [c.owner_id, c.id],
      )
      await fetch(SUPABASE_URL + '/functions/v1/send-notification', {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + SERVICE_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          user_id: c.owner_id,
          title: 'Заявки ждут ✨',
          body: `Заявок: ${count} — окно выбора скоро закроется`,
          data: { type: 'selection_reminder', invitation_id: c.id },
          template: { count },
        }),
      }).catch((e) => console.error('selection-reminder push failed', c.id, e))
      reminded.push(`${c.id} → ${count}`)
    }
    return new Response(JSON.stringify({ reminded }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('selection-reminder error', e)
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), {
      status: 500,
    })
  } finally {
    await db.end()
  }
})
