import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { sendBillingEmail } from '../_shared/billing-email.ts'

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }
    const token = authHeader.replace('Bearer ', '')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: { user }, error: userError } = await adminClient.auth.getUser(token)
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // GDPR teyit e-postası için adres+dil, satır silinmeden ÖNCE alınır (24.07 C3)
    const { data: delUserRow } = await adminClient
      .from('users')
      .select('billing_email, locale')
      .eq('id', user.id)
      .maybeSingle()

    // F2: hesap silinmeden ÖNCE aktif abonelik lokal iptal edilir ve iz billing_events'e
    // düşülür (subscriptions satırı CASCADE ile silinir; event user_id SET NULL ile kalır).
    // Bankada iptal endpoint'i yok — çekimi yalnız biz tetiklediğimiz için lokal iptal yeterli;
    // CofToken'ın bankadan tamamen silinmesi destek prosedürüne bağlı (bkz. docs/f2-billing-plan.md S4).
    const { data: subs } = await adminClient
      .from('subscriptions')
      .select('id, tochka_subscription_id, status')
      .eq('user_id', user.id)
      .in('status', ['pending_binding', 'active', 'past_due', 'cancelled'])
    if (subs && subs.length > 0) {
      await adminClient
        .from('subscriptions')
        .update({ auto_renew: false, status: 'cancelled', cancelled_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .in('status', ['pending_binding', 'active', 'past_due'])
      await adminClient.from('billing_events').insert(
        subs.map((s) => ({
          subscription_id: s.id,
          user_id: user.id,
          event: 'cancelled',
          detail: {
            reason: 'account_deleted',
            tochka_subscription_id: s.tochka_subscription_id,
            prev_status: s.status,
          },
        })),
      )
    }

    // GDPR: storage'daki fotoğraflar da silinir (user_photos satırı CASCADE ile
    // gider ama dosyalar API üzerinden ayrıca silinmeli). Hata olursa 500 dön —
    // henüz hesap silinmedi, kullanıcı yeniden deneyebilir.
    for (const bucket of ['profile-photos', 'selfies']) {
      const { data: files, error: listError } = await adminClient.storage
        .from(bucket)
        .list(user.id, { limit: 100 })
      if (listError) {
        return new Response(
          JSON.stringify({ error: `storage list failed (${bucket}): ${listError.message}` }),
          { status: 500, headers: { 'Content-Type': 'application/json' } },
        )
      }
      if (files && files.length > 0) {
        const paths = files.map((f) => `${user.id}/${f.name}`)
        const { error: removeError } = await adminClient.storage.from(bucket).remove(paths)
        if (removeError) {
          return new Response(
            JSON.stringify({ error: `storage remove failed (${bucket}): ${removeError.message}` }),
            { status: 500, headers: { 'Content-Type': 'application/json' } },
          )
        }
      }
    }

    // Silme hatası yutulmaz: 15.07 denetiminde matches FK'sı silmeyi bloklarken
    // buradaki hata görmezden gelinip auth silmeye geçiliyordu.
    const { error: usersDeleteError } = await adminClient
      .from('users')
      .delete()
      .eq('id', user.id)
    if (usersDeleteError) {
      return new Response(JSON.stringify({ error: usersDeleteError.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id)
    if (deleteError) {
      return new Response(JSON.stringify({ error: deleteError.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // GDPR silme teyidi — best effort, silme sonucunu etkilemez (24.07 C3)
    const delEmail = delUserRow?.billing_email as string | null
    if (delEmail) {
      await sendBillingEmail(delEmail, 'account_deleted', {},
        (delUserRow?.locale as string | null) ?? 'ru')
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
