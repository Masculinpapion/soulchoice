// billing-cron — F2 Faz 3: günlük abonelik döngüsü (FAZ A bildirim / B çekim / C kurtarma + digest + heartbeat).
// Host crontab günde 1 kez çağırır (10:25 MSK), SADECE service key ile.
//
// SAVUNMACI ÇEKİM POLİTİKASI (Mustafa çerçevesi + Точка S2/S3 cevapları, 09.07.2026):
// - Banka limiti: redde günde MAX 2 deneme → billing_config.max_daily_attempts (default 1) ASLA aşılmaz.
// - Çekimden ÖNCE Order-diff mutabakatı: önceki çekim aslında geçtiyse KAYDET, ÇEKME (çifte çekim koruması).
// - Yanıt sınıflandırması: result:true → GET teyidi → grant | açık hata → charge_fail, o gün biter,
//   retry sonraki günlük koşular (gün 0/+24s/+48s, KARAR 2) | TANINMAYAN biçim → charge_unknown,
//   o abonelik için otomatik deneme DURUR (digest'te kırmızı, manuel çözüm). Körlemesine retry YOK.
// - F2-1 kapısı (KARAR 3): push VEYA e-posta en az biri gönderilmemişse çekim YAPILMAZ.
// - dry_run=true iken hiçbir bildirim/çekim yapılmaz, sadece digest'e "yapılacaktı" listesi yazılır.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'
import { sendBillingEmail, sendCustomEmail } from '../_shared/billing-email.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''
const TOCHKA_API = 'https://enter.tochka.com/uapi'
const TOCHKA_JWT = Deno.env.get('TOCHKA_JWT_TOKEN') ?? ''
const CUSTOMER_CODE = Deno.env.get('TOCHKA_CUSTOMER_CODE') ?? '305892846'

interface Cfg {
  price_rub: number
  period_days: number
  grace_hours: number
  notify_before_hours: number
  min_notify_gap_hours: number
  dry_run: boolean
  max_daily_attempts: number
  digest_email: string
}

interface Candidate {
  id: string
  user_id: string
  status: string
  tochka_subscription_id: string
  next_billing_at: Date
  renewal_notified_at: Date | null
  retry_count: number
  price_paid: number
  billing_email: string | null
  premium_until: Date | null
}

interface TochkaOrder {
  orderId: string
  type: string
  amount: number
  time: string
}

function fmtDate(d: Date | string | null | undefined): string {
  if (!d) return ''
  const dt = new Date(d)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(dt.getDate())}.${p(dt.getMonth() + 1)}.${dt.getFullYear()}`
}

function fmtAmount(rub: number): string {
  return rub.toLocaleString('ru-RU') + ' ₽'
}

function jwtDaysLeft(): number | null {
  try {
    const payload = JSON.parse(atob(TOCHKA_JWT.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')))
    if (!payload?.exp) return null
    return Math.floor((payload.exp * 1000 - Date.now()) / 86400000)
  } catch {
    return null
  }
}

async function sendPush(userId: string, title: string, body: string): Promise<boolean> {
  try {
    const res = await fetch(SUPABASE_URL + '/functions/v1/send-notification', {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: 'Bearer ' + SERVICE_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ user_id: userId, title, body }),
    })
    return res.ok
  } catch {
    return false
  }
}

async function logEvent(db: Client, subId: string, userId: string | null, event: string, detail: unknown) {
  await db.queryObject(
    `insert into billing_events (subscription_id, user_id, event, detail) values ($1, $2, $3, $4::jsonb)`,
    [subId, userId, event, JSON.stringify(detail ?? {})],
  )
}

async function getOperation(operationId: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(
    `${TOCHKA_API}/acquiring/v1.0/payments/${encodeURIComponent(operationId)}?customerCode=${CUSTOMER_CODE}`,
    { headers: { Authorization: 'Bearer ' + TOCHKA_JWT } },
  )
  if (!res.ok) return null
  const json = await res.json().catch(() => null)
  return json?.Data?.Operation?.[0] ?? null
}

// Webhook ile aynı grant formülü — idempotency (operation_id, order_id) çifti
async function grantOrder(
  db: Client,
  sub: Candidate,
  order: TochkaOrder,
  op: Record<string, unknown>,
  periodDays: number,
  via: string,
): Promise<Date | null> {
  const ins = await db.queryObject<{ id: string }>(
    `insert into payments
       (user_id, operation_id, order_id, amount, currency, source, status, purpose,
        subscription_id, charge_type, paid_at, raw)
     select $1, $2, $3, $4, 'RUB',
            coalesce((select source from payments
                       where operation_id = $2 and charge_type = 'subscription_initial' limit 1), 'web'),
            'paid', $5, $6, 'subscription_renewal', $7::timestamptz, $8::jsonb
     on conflict (operation_id, order_id) do nothing
     returning id`,
    [sub.user_id, sub.tochka_subscription_id, order.orderId, order.amount,
     (op as { purpose?: string }).purpose ?? null, sub.id, order.time, JSON.stringify(op)],
  )
  if (ins.rows.length === 0) return null // webhook yarışı kazandı, uzatmayı o yaptı
  const prem = await db.queryObject<{ premium_until: Date }>(
    `update users
        set subscription_status = 'active', subscription_provider = 'tochka',
            premium_until = greatest(coalesce(premium_until, now()), now()) + make_interval(days => $2)
      where id = $1
      returning premium_until`,
    [sub.user_id, periodDays],
  )
  const until = prem.rows[0]?.premium_until ?? null
  await db.queryObject(
    `update subscriptions
        set status = 'active', expires_at = $2, next_billing_at = $2,
            retry_count = 0, grace_until = null
      where id = $1`,
    [sub.id, until],
  )
  await logEvent(db, sub.id, sub.user_id, 'charge_ok', {
    via, order_id: order.orderId, amount: order.amount, premium_until: until?.toISOString?.() ?? null,
  })
  return until
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok')
  const auth = req.headers.get('Authorization') ?? ''
  if (!SERVICE_KEY || auth !== 'Bearer ' + SERVICE_KEY) {
    return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403 })
  }

  const summary = {
    dry_run: true,
    notified: [] as string[],
    notify_failed: [] as string[],
    reconciled: [] as string[],
    charged: [] as string[],
    charge_failed: [] as string[],
    charge_unknown: [] as string[],
    pending_verify: [] as string[],
    downgraded: [] as string[],
    expired_bindings: 0,
    would_notify: [] as string[],
    would_charge: [] as string[],
    jwt_days_left: jwtDaysLeft(),
    errors: [] as string[],
  }
  let heartbeatStatus = 'ok'

  const db = new Client(DB_URL)
  await db.connect()
  try {
    const cfgRes = await db.queryObject<Cfg>(`select * from billing_config where id = 1`)
    const cfg = cfgRes.rows[0]
    if (!cfg) throw new Error('billing_config yok')
    summary.dry_run = cfg.dry_run

    // ================= FAZ A — BİLDİRİM (F2-1 kapısı) =================
    const notifyCands = await db.queryObject<Candidate>(
      `select s.id, s.user_id, s.status, s.tochka_subscription_id, s.next_billing_at,
              s.renewal_notified_at, s.retry_count, s.price_paid, u.billing_email, u.premium_until
         from subscriptions s join users u on u.id = s.user_id
        where s.status = 'active' and s.auto_renew and s.tochka_subscription_id is not null
          and s.next_billing_at <= now() + make_interval(hours => $1)
          and (s.renewal_notified_at is null
               or s.renewal_notified_at < s.next_billing_at - interval '72 hours')`,
      [cfg.notify_before_hours],
    )
    for (const sub of notifyCands.rows) {
      const label = `${sub.tochka_subscription_id.slice(0, 8)} (${fmtAmount(sub.price_paid)})`
      if (cfg.dry_run) {
        summary.would_notify.push(label)
        continue
      }
      const amount = fmtAmount(sub.price_paid)
      const pushOk = await sendPush(sub.user_id, 'SoulChoice Premium',
        `Подписка продлится завтра — спишется ${amount}. Управление — в профиле.`)
      const mail = sub.billing_email
        ? await sendBillingEmail(sub.billing_email, 'renewal_reminder', { amount })
        : { ok: false, error: 'no_billing_email' }
      const channels = [...(pushOk ? ['push'] : []), ...(mail.ok ? ['email'] : [])]
      if (channels.length > 0) {
        await db.queryObject(
          `update subscriptions set renewal_notified_at = now(), notified_channels = $2 where id = $1`,
          [sub.id, channels],
        )
        await logEvent(db, sub.id, sub.user_id, 'notified', { channels, email_error: mail.ok ? null : mail.error })
        summary.notified.push(label)
      } else {
        await logEvent(db, sub.id, sub.user_id, 'notify_failed', { email_error: mail.error ?? null })
        summary.notify_failed.push(label)
        heartbeatStatus = 'warn'
      }
    }

    // ================= FAZ B — ÇEKİM =================
    const chargeCands = await db.queryObject<Candidate>(
      `select s.id, s.user_id, s.status, s.tochka_subscription_id, s.next_billing_at,
              s.renewal_notified_at, s.retry_count, s.price_paid, u.billing_email, u.premium_until
         from subscriptions s join users u on u.id = s.user_id
        where s.status in ('active', 'past_due') and s.auto_renew
          and s.tochka_subscription_id is not null
          and s.next_billing_at <= now()
          and s.retry_count < 3
          -- F2-1 kapısı: bu döngü için bildirim var VE en az min_notify_gap saat önce
          and s.renewal_notified_at is not null
          and s.renewal_notified_at > s.next_billing_at - interval '72 hours'
          and s.renewal_notified_at <= now() - make_interval(hours => $1)
          -- charge_unknown kilidi: son çekim-sonucu eventi unknown ise otomatik deneme DURUR
          and coalesce((select be.event from billing_events be
                         where be.subscription_id = s.id
                           and be.event in ('charge_ok', 'charge_fail', 'charge_unknown')
                         order by be.created_at desc limit 1), '') <> 'charge_unknown'
          -- S3 banka limiti: son 20 saatteki deneme sayısı max_daily_attempts altında
          and (select count(*) from billing_events be
                where be.subscription_id = s.id and be.event = 'charge_attempt'
                  and be.created_at > now() - interval '20 hours') < $2`,
      [cfg.min_notify_gap_hours, cfg.max_daily_attempts],
    )

    for (const sub of chargeCands.rows) {
      const label = `${sub.tochka_subscription_id.slice(0, 8)} (${fmtAmount(sub.price_paid)})`
      try {
        // ÇEKİMDEN ÖNCE MUTABAKAT: işlenmemiş çekim var mı? Varsa kaydet, ÇEKME.
        const op = await getOperation(sub.tochka_subscription_id)
        if (op) {
          const orders = ((op.Order ?? []) as TochkaOrder[])
            .filter((o) => o?.orderId && o?.type === 'approval')
            .sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime())
          const known = await db.queryObject<{ order_id: string }>(
            `select order_id from payments where operation_id = $1 and order_id <> ''`,
            [sub.tochka_subscription_id],
          )
          const knownIds = new Set(known.rows.map((r) => r.order_id))
          const missing = orders.filter((o) => !knownIds.has(o.orderId))
          if (missing.length > 0) {
            for (const o of missing) await grantOrder(db, sub, o, op, cfg.period_days, 'cron_reconcile')
            summary.reconciled.push(label)
            continue // bu döngü ödenmiş sayılır, çekim yok
          }
        }

        if (cfg.dry_run) {
          summary.would_charge.push(label)
          continue
        }

        // Deneme kaydı ÖNCE düşülür — çökme/yeniden koşma max_daily_attempts'i aşamaz
        await logEvent(db, sub.id, sub.user_id, 'charge_attempt', {
          amount: sub.price_paid, retry_no: sub.retry_count + 1,
        })

        let cls: 'ok' | 'fail' | 'unknown' = 'unknown'
        let rawBody = ''
        try {
          const res = await fetch(
            `${TOCHKA_API}/acquiring/v1.0/subscriptions/${encodeURIComponent(sub.tochka_subscription_id)}/charge`,
            {
              method: 'POST',
              headers: { Authorization: 'Bearer ' + TOCHKA_JWT, 'Content-Type': 'application/json' },
              body: JSON.stringify({ Data: { amount: Number(sub.price_paid).toFixed(2) } }),
            },
          )
          rawBody = (await res.text()).slice(0, 1000)
          let parsed: Record<string, unknown> | null = null
          try {
            parsed = JSON.parse(rawBody)
          } catch { /* parse edilemedi → sınıflandırma aşağıda */ }
          const result = (parsed as { Data?: { result?: unknown } } | null)?.Data?.result
          if (res.status === 200 && result === true) cls = 'ok'
          else if (!res.ok || result === false || (parsed as { Errors?: unknown } | null)?.Errors) cls = 'fail'
          else cls = 'unknown' // 200 ama tanınmayan gövde — para durumu belirsiz, DUR
        } catch (e) {
          cls = 'fail' // ağ hatası: çekim gitmedi varsayımı güvenli, banka mutabakatı ertesi koşuda yakalar
          rawBody = String(e?.message ?? e)
        }

        if (cls === 'ok') {
          await new Promise((r) => setTimeout(r, 15000)) // Order kaydının düşmesini bekle
          const op2 = await getOperation(sub.tochka_subscription_id)
          const orders2 = (((op2?.Order ?? []) as TochkaOrder[]))
            .filter((o) => o?.orderId && o?.type === 'approval')
            .sort((a, b) => new Date(b.time).getTime() - new Date(a.time).getTime())
          const known2 = await db.queryObject<{ order_id: string }>(
            `select order_id from payments where operation_id = $1 and order_id <> ''`,
            [sub.tochka_subscription_id],
          )
          const known2Ids = new Set(known2.rows.map((r) => r.order_id))
          const fresh = orders2.find((o) => !known2Ids.has(o.orderId))
          if (fresh && op2) {
            const until = await grantOrder(db, sub, fresh, op2, cfg.period_days, 'cron')
            const dateStr = fmtDate(until)
            await sendPush(sub.user_id, 'SoulChoice Premium',
              `Подписка продлена. Premium активен до ${dateStr}.`)
            if (sub.billing_email) await sendBillingEmail(sub.billing_email, 'renewal_success', { date: dateStr })
            summary.charged.push(label)
          } else {
            // result:true ama Order henüz görünmüyor — grant yok, ertesi koşuda mutabakat tamamlar
            await logEvent(db, sub.id, sub.user_id, 'charge_pending_verify', { raw: rawBody })
            summary.pending_verify.push(label)
            heartbeatStatus = 'warn'
          }
        } else if (cls === 'fail') {
          const newRetry = sub.retry_count + 1
          await db.queryObject(
            `update subscriptions
                set retry_count = $2, status = 'past_due',
                    grace_until = case when $2 >= 3 then now() + make_interval(hours => $3)
                                       else now() + interval '72 hours' end
              where id = $1`,
            [sub.id, newRetry, cfg.grace_hours],
          )
          await logEvent(db, sub.id, sub.user_id, 'charge_fail', { raw: rawBody, retry_no: newRetry })
          await sendPush(sub.user_id, 'SoulChoice Premium',
            'Не удалось продлить подписку — проверьте карту. Premium пока активен, мы повторим попытку.')
          if (sub.billing_email) await sendBillingEmail(sub.billing_email, 'renewal_failed', {})
          summary.charge_failed.push(`${label} → ${rawBody.slice(0, 120)}`)
          heartbeatStatus = 'warn'
        } else {
          await logEvent(db, sub.id, sub.user_id, 'charge_unknown', { raw: rawBody })
          summary.charge_unknown.push(`${label} → ${rawBody.slice(0, 120)}`)
          heartbeatStatus = 'error'
        }
      } catch (e) {
        summary.errors.push(`${label}: ${String(e?.message ?? e)}`)
        heartbeatStatus = 'error'
      }
    }

    // ================= FAZ C — KURTARMA / DÜŞÜŞ =================
    if (!cfg.dry_run) {
      const down = await db.queryObject<{ id: string; user_id: string }>(
        `update subscriptions
            set status = 'expired', auto_renew = false
          where status = 'past_due' and grace_until is not null and grace_until < now()
          returning id, user_id`,
      )
      for (const d of down.rows) {
        await logEvent(db, d.id, d.user_id, 'downgraded', { reason: 'grace_expired' })
        summary.downgraded.push(d.id.slice(0, 8))
      }
    }
    const expiredBindings = await db.queryObject<{ id: string }>(
      `update subscriptions set status = 'expired'
        where status = 'pending_binding' and created_at < now() - interval '7 days'
        returning id`,
    )
    summary.expired_bindings = expiredBindings.rows.length
    await db.queryObject(
      `update payments set status = 'expired'
        where status = 'pending' and charge_type = 'subscription_initial'
          and created_at < now() - interval '7 days'`,
    )

    // ================= DIGEST (P2) + JWT ALARMI (P7) =================
    const red = summary.charge_unknown.length > 0 || summary.errors.length > 0
    const jwtWarn = summary.jwt_days_left != null && summary.jwt_days_left < 90
    const lines = [
      `SoulChoice billing-cron — ${new Date().toISOString().slice(0, 16)} UTC${cfg.dry_run ? ' [DRY-RUN]' : ''}`,
      '',
      `Bildirim: ${summary.notified.length} ok, ${summary.notify_failed.length} başarısız`,
      `Çekim: ${summary.charged.length} ok, ${summary.charge_failed.length} başarısız, ${summary.charge_unknown.length} BELİRSİZ, ${summary.pending_verify.length} teyit bekliyor, ${summary.reconciled.length} mutabakatla kapandı`,
      `Düşüş: ${summary.downgraded.length} abonelik sona erdi; ${summary.expired_bindings} bağlanmamış kayıt temizlendi`,
      cfg.dry_run ? `DRY-RUN listeleri → bildirilecekti: [${summary.would_notify.join('; ') || '—'}] / çekilecekti: [${summary.would_charge.join('; ') || '—'}]` : '',
      summary.charge_failed.length ? `Başarısız: ${summary.charge_failed.join(' | ')}` : '',
      summary.charge_unknown.length ? `⚠️ BELİRSİZ (manuel bakılacak): ${summary.charge_unknown.join(' | ')}` : '',
      summary.errors.length ? `⚠️ Hatalar: ${summary.errors.join(' | ')}` : '',
      jwtWarn ? `⚠️ Точка JWT süresine ${summary.jwt_days_left} gün kaldı — token yenile!` : `Точка JWT: ${summary.jwt_days_left ?? '?'} gün`,
    ].filter((l) => l !== '')
    const subject = `${red ? '⚠️ ' : ''}SoulChoice billing: ${summary.charged.length} çekim, ${summary.charge_failed.length} hata${cfg.dry_run ? ' [DRY-RUN]' : ''}`
    if (cfg.digest_email) await sendCustomEmail(cfg.digest_email, subject, lines.join('\n'))
    await db.queryObject(
      `insert into billing_events (event, detail) values ('digest', $1::jsonb)`,
      [JSON.stringify(summary)],
    )

    // ================= HEARTBEAT (P3) =================
    await db.queryObject(
      `insert into cron_heartbeat (job, last_run_at, last_status, detail)
       values ('billing-cron', now(), $1, $2::jsonb)
       on conflict (job) do update set last_run_at = now(), last_status = $1, detail = $2::jsonb`,
      [heartbeatStatus, JSON.stringify({
        charged: summary.charged.length, failed: summary.charge_failed.length,
        unknown: summary.charge_unknown.length, dry_run: cfg.dry_run,
      })],
    )

    return new Response(JSON.stringify(summary), { headers: { 'Content-Type': 'application/json' } })
  } catch (e) {
    console.error('billing-cron fatal', e)
    try {
      await db.queryObject(
        `insert into cron_heartbeat (job, last_run_at, last_status, detail)
         values ('billing-cron', now(), 'error', $1::jsonb)
         on conflict (job) do update set last_run_at = now(), last_status = 'error', detail = $1::jsonb`,
        [JSON.stringify({ fatal: String(e?.message ?? e) })],
      )
    } catch (_) { /* heartbeat bile yazılamadı — status endpoint yaşlanmayı gösterecek */ }
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), { status: 500 })
  } finally {
    await db.end()
  }
})
