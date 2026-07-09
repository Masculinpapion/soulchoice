// _shared/billing-email.ts — F2 işlem e-postaları (Timeweb SMTP, onaylı §7 metinleri)
// Şifre/kimlik SADECE env'den (BILLING_SMTP_*) okunur; koda/loga yazılmaz.
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts'

const HOST = Deno.env.get('BILLING_SMTP_HOST') ?? ''
const PORT = Number(Deno.env.get('BILLING_SMTP_PORT') ?? '465')
const USER = Deno.env.get('BILLING_SMTP_USER') ?? ''
const PASS = Deno.env.get('BILLING_SMTP_PASS') ?? ''

export type BillingEmailKind =
  | 'renewal_reminder'
  | 'renewal_success'
  | 'renewal_failed'
  | 'cancel_confirm'

export interface BillingEmailParams {
  date?: string // DD.MM.YYYY
  amount?: string // örn "1 000 ₽"
}

const FOOTER =
  '\n\n—\nSoulChoice Premium. Управление подпиской: приложение (Профиль → Подписка) или https://soulchoice.app/premium\nПисьмо отправлено автоматически. Вопросы: support@soulchoice.app'

function template(kind: BillingEmailKind, p: BillingEmailParams): { subject: string; body: string } {
  switch (kind) {
    case 'renewal_reminder':
      return {
        subject: 'Завтра продление подписки SoulChoice Premium',
        body:
          `Подписка SoulChoice Premium продлится завтра — спишется ${p.amount ?? '1 000 ₽'}. Управление — в профиле.` +
          FOOTER,
      }
    case 'renewal_success':
      return {
        subject: 'Подписка SoulChoice Premium продлена',
        body: `Подписка продлена. Premium активен до ${p.date ?? ''}.` + FOOTER,
      }
    case 'renewal_failed':
      return {
        subject: 'Не удалось продлить подписку SoulChoice Premium',
        body:
          'Не удалось продлить подписку — проверьте карту. Premium пока активен, мы повторим попытку.' +
          FOOTER,
      }
    case 'cancel_confirm':
      return {
        subject: 'Подписка SoulChoice Premium отменена',
        body: `Подписка отменена. Premium активен до ${p.date ?? ''}.` + FOOTER,
      }
  }
}

// Dönüş: { ok } — çağıran taraf billing_events'e yazar. Hata fırlatmaz.
export async function sendBillingEmail(
  to: string,
  kind: BillingEmailKind,
  params: BillingEmailParams = {},
): Promise<{ ok: boolean; error?: string }> {
  if (!HOST || !USER || !PASS) return { ok: false, error: 'smtp_not_configured' }
  if (!to || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) return { ok: false, error: 'bad_recipient' }

  const { subject, body } = template(kind, params)
  const client = new SMTPClient({
    connection: { hostname: HOST, port: PORT, tls: true, auth: { username: USER, password: PASS } },
  })
  try {
    await Promise.race([
      client.send({ from: `SoulChoice <${USER}>`, to, subject, content: body }),
      new Promise((_, rej) => setTimeout(() => rej(new Error('smtp_timeout')), 20000)),
    ])
    return { ok: true }
  } catch (e) {
    console.error('billing email failed', kind, e?.message ?? e)
    return { ok: false, error: String(e?.message ?? e) }
  } finally {
    try {
      await client.close()
    } catch (_) { /* kapatma hatası önemsiz */ }
  }
}
