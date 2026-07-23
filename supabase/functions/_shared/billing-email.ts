// _shared/billing-email.ts — F2 işlem e-postaları (Timeweb SMTP, onaylı §7 metinleri)
// 09.07.2026 render fix: denomailer'ın çok parçalı/attachment'lı çıktısı Gmail'de bozuk
// görünüyordu (ham quoted-printable gövde + ham encoded konu). Artık ham SMTP (465/TLS) +
// elle kurulan MIME: tek text/plain; charset=utf-8 gövde, base64 CTE, konu RFC 2047 (UTF-8 B).
// Şifre/kimlik SADECE env'den (BILLING_SMTP_*) okunur; koda/loga yazılmaz.

const HOST = Deno.env.get('BILLING_SMTP_HOST') ?? ''
const PORT = Number(Deno.env.get('BILLING_SMTP_PORT') ?? '465')
const USER = Deno.env.get('BILLING_SMTP_USER') ?? ''
const PASS = Deno.env.get('BILLING_SMTP_PASS') ?? ''

export type BillingEmailKind =
  | 'renewal_reminder'
  | 'purchase_success'
  | 'renewal_success'
  | 'renewal_failed'
  | 'cancel_confirm'
  | 'welcome'        // D+0 — servis tonu, fiyat/teklif YOK (rızasız da gider)
  | 'premium_intro'  // D+2 — SADECE pazarlama rızalılara (ФЗ-38)

export interface BillingEmailParams {
  date?: string // DD.MM.YYYY
  amount?: string // örn "1 000 ₽"
}

const FOOTER =
  '\n\n—\nSoulChoice Premium. Управление подпиской: приложение (Профиль → Подписка) или https://soulchoice.app/premium\nПисьмо отправлено автоматически. Вопросы: support@soulchoice.app'

function template(kind: BillingEmailKind, p: BillingEmailParams): { subject: string; body: string } {
  switch (kind) {
    case 'renewal_reminder':
      // notify_before_hours artık 72 saat — "завтра" yanlış olur, tarih yazılır
      return {
        subject: p.date
          ? `Продление подписки SoulChoice Premium — ${p.date}`
          : 'Скоро продление подписки SoulChoice Premium',
        body:
          `Подписка SoulChoice Premium продлится ${p.date ?? 'в ближайшие дни'} — спишется ${p.amount ?? '1 000 ₽'}. Управление — в профиле.` +
          FOOTER,
      }
    case 'purchase_success':
      return {
        subject: 'Подписка SoulChoice Premium оформлена',
        body: `Подписка оформлена. Premium активен до ${p.date ?? ''}.` + FOOTER,
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
    case 'welcome':
      return {
        subject: 'Добро пожаловать в SoulChoice',
        body:
          'Привет! Ты в SoulChoice — приложении для тех, кто выбирает живое общение.\n\n' +
          'С чего начать: создай приглашение на ужин, концерт или прогулку — или откликнись на чужое. Дальше всё решает взаимный выбор.\n\n' +
          'Вопросы: support@soulchoice.app' + FOOTER,
      }
    case 'premium_intro':
      return {
        subject: 'SoulChoice Premium — безлимитные приглашения и заявки',
        body:
          'Premium открывает: безлимитные приглашения и заявки, чат после взаимного выбора, приоритет модерации.\n\n' +
          'Подписка — 1000 ₽ каждые 30 дней с автопродлением (отмена в любой момент, в один клик) или разовый доступ на 30 дней.\n\n' +
          'Оформить: https://soulchoice.app/premium\n\n' +
          '—\nВы получили это письмо, потому что дали согласие на новости SoulChoice.\nОтписаться: напишите на support@soulchoice.app',
      }
  }
}

const encoder = new TextEncoder()
const decoder = new TextDecoder()

function b64(bytes: Uint8Array): string {
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin)
}

// RFC 2047: encoded-word ≤75 karakter — UTF-8 KARAKTER sınırında böl, satır katlamayla birleştir
function encodeSubject(s: string): string {
  const chunks: number[][] = []
  let cur: number[] = []
  for (const ch of s) {
    const bytes = encoder.encode(ch)
    if (cur.length + bytes.length > 42) {
      chunks.push(cur)
      cur = []
    }
    cur.push(...bytes)
  }
  if (cur.length) chunks.push(cur)
  return chunks.map((c) => `=?UTF-8?B?${b64(Uint8Array.from(c))}?=`).join('\r\n ')
}

function encodeBody(s: string): string {
  const full = b64(encoder.encode(s))
  return full.match(/.{1,76}/g)?.join('\r\n') ?? full
}

async function readReply(reader: ReadableStreamDefaultReader<Uint8Array>): Promise<string> {
  let data = ''
  while (true) {
    const { value, done } = await reader.read()
    if (done) throw new Error('smtp_connection_closed')
    data += decoder.decode(value)
    if (!data.endsWith('\r\n')) continue
    const lines = data.split('\r\n').filter((l) => l.length > 0)
    const last = lines[lines.length - 1]
    if (/^\d{3} /.test(last)) return last // çok satırlı yanıtın (250-...) son satırı
  }
}

async function smtpSend(to: string, subject: string, body: string): Promise<void> {
  const conn = await Deno.connectTls({ hostname: HOST, port: PORT })
  const reader = conn.readable.getReader()
  const writer = conn.writable.getWriter()

  const send = (line: string) => writer.write(encoder.encode(line + '\r\n'))
  const step = async (cmd: string | null, expectCode: string) => {
    if (cmd !== null) await send(cmd)
    const reply = await readReply(reader)
    if (!reply.startsWith(expectCode)) throw new Error(`smtp_unexpected: ${reply.slice(0, 80)}`)
    return reply
  }

  try {
    await step(null, '220')
    await step('EHLO soulchoice.app', '250')
    await step('AUTH LOGIN', '334')
    await step(b64(encoder.encode(USER)), '334')
    await step(b64(encoder.encode(PASS)), '235')
    await step(`MAIL FROM:<${USER}>`, '250')
    await step(`RCPT TO:<${to}>`, '250')
    await step('DATA', '354')
    const message = [
      `From: SoulChoice <${USER}>`,
      `To: <${to}>`,
      `Subject: ${encodeSubject(subject)}`,
      `Date: ${new Date().toUTCString()}`,
      `Message-ID: <${crypto.randomUUID()}@soulchoice.app>`,
      'MIME-Version: 1.0',
      'Content-Type: text/plain; charset=utf-8',
      'Content-Transfer-Encoding: base64',
      '',
      encodeBody(body),
      '.',
    ].join('\r\n')
    await step(message, '250')
    await send('QUIT')
  } finally {
    try {
      conn.close()
    } catch (_) { /* zaten kapalı */ }
  }
}

// Serbest konu/gövde ile gönderim (digest vb. iç kullanım). Hata fırlatmaz.
export async function sendCustomEmail(
  to: string,
  subject: string,
  body: string,
): Promise<{ ok: boolean; error?: string }> {
  if (!HOST || !USER || !PASS) return { ok: false, error: 'smtp_not_configured' }
  if (!to || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) return { ok: false, error: 'bad_recipient' }
  try {
    await Promise.race([
      smtpSend(to, subject, body),
      new Promise((_, rej) => setTimeout(() => rej(new Error('smtp_timeout')), 20000)),
    ])
    return { ok: true }
  } catch (e) {
    console.error('custom email failed', e?.message ?? e)
    return { ok: false, error: String(e?.message ?? e) }
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
  try {
    await Promise.race([
      smtpSend(to, subject, body),
      new Promise((_, rej) => setTimeout(() => rej(new Error('smtp_timeout')), 20000)),
    ])
    return { ok: true }
  } catch (e) {
    console.error('billing email failed', kind, e?.message ?? e)
    return { ok: false, error: String(e?.message ?? e) }
  }
}
