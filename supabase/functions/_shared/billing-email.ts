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
  | 'premium_expired' // grace bitti / abonelik kapandı (24.07)
  | 'account_deleted' // GDPR silme teyidi (24.07)
  | 'welcome'        // D+0 — servis tonu, fiyat/teklif YOK (rızasız da gider)
  | 'premium_intro'  // D+2 — SADECE pazarlama rızalılara (ФЗ-38)

export interface BillingEmailParams {
  date?: string // DD.MM.YYYY
  amount?: string // örn "1 000 ₽"
}

// 24.07 i18n: işlemsel türler alıcının dilinde (users.locale, fallback ru);
// welcome/premium_intro pazarlama kopyası — RU kalır (yeni kopya = Mustafa onayı).
const FOOTERS: Record<string, string> = {
  ru: '\n\n—\nSoulChoice Premium. Управление подпиской: приложение (Профиль → Подписка) или https://soulchoice.app/premium\nПисьмо отправлено автоматически. Вопросы: support@soulchoice.app',
  tr: '\n\n—\nSoulChoice Premium. Abonelik yönetimi: uygulama (Profil → Abonelik) veya https://soulchoice.app/premium\nBu e-posta otomatik gönderildi. Sorular: support@soulchoice.app',
  en: '\n\n—\nSoulChoice Premium. Manage your subscription: the app (Profile → Subscription) or https://soulchoice.app/premium\nThis email was sent automatically. Questions: support@soulchoice.app',
}
const FOOTER = FOOTERS.ru

function template(kind: BillingEmailKind, p: BillingEmailParams, locale = 'ru'): { subject: string; body: string } {
  const L = (locale === 'tr' || locale === 'en') ? locale : 'ru'
  const F = FOOTERS[L]
  const pick = (m: Record<string, { subject: string; body: string }>) => {
    const v = m[L] ?? m.ru
    return { subject: v.subject, body: v.body + F }
  }
  switch (kind) {
    case 'renewal_reminder':
      return pick({
        ru: { subject: p.date ? `Продление подписки SoulChoice Premium — ${p.date}` : 'Скоро продление подписки SoulChoice Premium',
              body: `Подписка SoulChoice Premium продлится ${p.date ?? 'в ближайшие дни'} — спишется ${p.amount ?? '1 000 ₽'}. Управление — в профиле.` },
        tr: { subject: p.date ? `SoulChoice Premium yenilenmesi — ${p.date}` : 'SoulChoice Premium aboneliğin yakında yenilenecek',
              body: `SoulChoice Premium aboneliğin ${p.date ?? 'önümüzdeki günlerde'} yenilenecek — ${p.amount ?? '1 000 ₽'} çekilecek. Yönetim: profil.` },
        en: { subject: p.date ? `SoulChoice Premium renewal — ${p.date}` : 'Your SoulChoice Premium renews soon',
              body: `Your SoulChoice Premium renews on ${p.date ?? 'the coming days'} — ${p.amount ?? '1,000 ₽'} will be charged. Manage it in your profile.` },
      })
    case 'purchase_success':
      return pick({
        ru: { subject: 'Подписка SoulChoice Premium оформлена', body: `Подписка оформлена. Premium активен до ${p.date ?? ''}.` },
        tr: { subject: 'SoulChoice Premium aboneliğin başladı', body: `Aboneliğin başladı. Premium ${p.date ?? ''} tarihine kadar aktif.` },
        en: { subject: 'Your SoulChoice Premium subscription has started', body: `Your subscription has started. Premium is active until ${p.date ?? ''}.` },
      })
    case 'renewal_success':
      return pick({
        ru: { subject: 'Подписка SoulChoice Premium продлена', body: `Подписка продлена. Premium активен до ${p.date ?? ''}.` },
        tr: { subject: 'SoulChoice Premium aboneliğin yenilendi', body: `Aboneliğin yenilendi. Premium ${p.date ?? ''} tarihine kadar aktif.` },
        en: { subject: 'Your SoulChoice Premium has been renewed', body: `Subscription renewed. Premium is active until ${p.date ?? ''}.` },
      })
    case 'renewal_failed':
      return pick({
        ru: { subject: 'Не удалось продлить подписку SoulChoice Premium',
              body: 'Не удалось продлить подписку — проверьте карту. Premium пока активен, мы повторим попытку.' },
        tr: { subject: 'SoulChoice Premium aboneliğin yenilenemedi',
              body: 'Abonelik yenilenemedi — kartını kontrol et. Premium şimdilik aktif, tekrar deneyeceğiz.' },
        en: { subject: "We couldn't renew your SoulChoice Premium",
              body: "We couldn't renew your subscription — please check your card. Premium is still active; we'll retry." },
      })
    case 'cancel_confirm':
      return pick({
        ru: { subject: 'Подписка SoulChoice Premium отменена', body: `Подписка отменена. Premium активен до ${p.date ?? ''}.` },
        tr: { subject: 'SoulChoice Premium aboneliğin iptal edildi', body: `Aboneliğin iptal edildi. Premium ${p.date ?? ''} tarihine kadar aktif.` },
        en: { subject: 'Your SoulChoice Premium has been cancelled', body: `Subscription cancelled. Premium is active until ${p.date ?? ''}.` },
      })
    case 'premium_expired':
      return pick({
        ru: { subject: 'Подписка SoulChoice Premium завершена',
              body: 'Подписка завершилась, Premium отключён. Возобновить можно в любой момент: приложение (Профиль → Подписка) или https://soulchoice.app/premium' },
        tr: { subject: 'SoulChoice Premium aboneliğin sona erdi',
              body: 'Aboneliğin sona erdi, Premium kapandı. İstediğin an yeniden başlatabilirsin: uygulama (Profil → Abonelik) veya https://soulchoice.app/premium' },
        en: { subject: 'Your SoulChoice Premium has ended',
              body: 'Your subscription has ended and Premium is off. Restart anytime: the app (Profile → Subscription) or https://soulchoice.app/premium' },
      })
    case 'account_deleted':
      return pick({
        ru: { subject: 'Аккаунт SoulChoice удалён',
              body: 'Ваш аккаунт и данные удалены без возможности восстановления. Спасибо, что были с нами.\n\nЕсли это были не вы — напишите на support@soulchoice.app.' },
        tr: { subject: 'SoulChoice hesabın silindi',
              body: 'Hesabın ve verilerin geri getirilemez şekilde silindi. Bizimle olduğun için teşekkürler.\n\nBu işlemi sen yapmadıysan support@soulchoice.app adresine yaz.' },
        en: { subject: 'Your SoulChoice account has been deleted',
              body: 'Your account and data have been permanently deleted. Thank you for being with us.\n\nIf this was not you, contact support@soulchoice.app.' },
      })
    case 'welcome':
      return pick({
        ru: { subject: 'Добро пожаловать в SoulChoice',
              body: 'Привет! Ты в SoulChoice — приложении для тех, кто выбирает живое общение.\n\nС чего начать: создай приглашение на ужин, концерт или прогулку — или откликнись на чужое. Дальше всё решает взаимный выбор.\n\nВопросы: support@soulchoice.app' },
        tr: { subject: "SoulChoice'a hoş geldin",
              body: 'Merhaba! SoulChoice, canlı buluşmayı seçenlerin uygulaması.\n\nNereden başlamalı: akşam yemeği, konser veya yürüyüş için bir davet oluştur — ya da birininkine başvur. Gerisini karşılıklı seçim belirler.\n\nSorular: support@soulchoice.app' },
        en: { subject: 'Welcome to SoulChoice',
              body: "Hi! You're on SoulChoice — the app for people who choose real connection.\n\nWhere to start: create an invitation for dinner, a concert or a walk — or apply to someone else's. Mutual choice decides the rest.\n\nQuestions: support@soulchoice.app" },
      })
    case 'premium_intro': {
      const intro = {
        ru: { subject: 'SoulChoice Premium — безлимитные приглашения и заявки',
              body: 'Premium открывает: безлимитные приглашения и заявки, чат после взаимного выбора, приоритет модерации.\n\nПодписка — 1000 ₽ каждые 30 дней с автопродлением (отмена в любой момент, в один клик) или разовый доступ на 30 дней.\n\nОформить: https://soulchoice.app/premium\n\n—\nВы получили это письмо, потому что дали согласие на новости SoulChoice.\nОтписаться: напишите на support@soulchoice.app' },
        tr: { subject: 'SoulChoice Premium — sınırsız davet ve başvuru',
              body: 'Premium ile: sınırsız davet ve başvuru, karşılıklı seçim sonrası sohbet, moderasyonda öncelik.\n\nAbonelik — otomatik yenilemeyle 30 günde bir 1000 ₽ (istediğin an tek tıkla iptal) veya 30 günlük tek seferlik erişim.\n\nBaşlat: https://soulchoice.app/premium\n\n—\nBu e-postayı SoulChoice haberlerine onay verdiğin için aldın.\nAbonelikten çık: support@soulchoice.app adresine yaz' },
        en: { subject: 'SoulChoice Premium — unlimited invitations and applications',
              body: 'Premium unlocks: unlimited invitations and applications, chat after mutual choice, moderation priority.\n\nSubscription — 1,000 ₽ every 30 days with auto-renewal (cancel anytime, one tap) or one-time 30-day access.\n\nGet it: https://soulchoice.app/premium\n\n—\nYou received this email because you opted in to SoulChoice news.\nUnsubscribe: email support@soulchoice.app' },
      }
      const v = intro[(locale === 'tr' || locale === 'en') ? locale : 'ru'] ?? intro.ru
      return { subject: v.subject, body: v.body }
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
  locale = 'ru',
): Promise<{ ok: boolean; error?: string }> {
  if (!HOST || !USER || !PASS) return { ok: false, error: 'smtp_not_configured' }
  if (!to || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) return { ok: false, error: 'bad_recipient' }

  const { subject, body } = template(kind, params, locale)
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
