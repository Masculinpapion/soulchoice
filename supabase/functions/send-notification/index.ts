import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
}

const DB_URL = Deno.env.get('SUPABASE_DB_URL') ?? ''
const PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID') ?? ''
const CLIENT_EMAIL = Deno.env.get('FIREBASE_CLIENT_EMAIL') ?? ''
const PRIVATE_KEY_RAW = (Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '').replace(/\\n/g, '\n')

async function getFcmAccessToken(): Promise<string> {
  const privateKey = await jose.importPKCS8(PRIVATE_KEY_RAW, 'RS256')
  const now = Math.floor(Date.now() / 1000)
  const jwt = await new jose.SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuer(CLIENT_EMAIL)
    .setSubject(CLIENT_EMAIL)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey)
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  })
  const data = await res.json()
  return data.access_token
}

// Alıcının DİLİNDE şablonlar (users.locale; yoksa ru). Şablonu olan tür için
// istemcinin gönderdiği title/body her zaman EZİLİR — böylece:
//  1) push alıcının dilinde gider (gönderenin değil),
//  2) new_message İÇERİK TAŞIMAZ (kilit ekranı gizliliği, Mustafa kararı 15.07)
//     — eski APK içerik gönderse bile sunuca takılır.
const TEMPLATES: Record<string, Record<string, { t: string; b: string }>> = {
  selected: {
    ru: { t: 'Тебя выбрали! 🎉', b: '{name} выбрал(а) тебя — чат открыт' },
    tr: { t: 'Seçildin! 🎉', b: '{name} seni seçti — sohbet açıldı' },
    en: { t: "You're selected! 🎉", b: '{name} chose you — chat is open' },
  },
  new_application: {
    ru: { t: 'Новая заявка 🔔', b: '{name} хочет присоединиться' },
    tr: { t: 'Yeni başvuru 🔔', b: '{name} katılmak istiyor' },
    en: { t: 'New application 🔔', b: '{name} wants to join' },
  },
  new_message: {
    ru: { t: '💬 {name}', b: 'Новое сообщение' },
    tr: { t: '💬 {name}', b: 'Yeni mesaj' },
    en: { t: '💬 {name}', b: 'New message' },
  },
  selection_reminder: {
    ru: { t: 'Заявки ждут ✨', b: 'Заявок: {count} — окно выбора скоро закроется' },
    tr: { t: 'Başvurular bekliyor ✨', b: '{count} başvuran seçimini bekliyor — pencere yakında kapanıyor' },
    en: { t: 'Applications waiting ✨', b: '{count} applicants await your choice — window closes soon' },
  },
  // Selfie kararı push'ları DB trigger'ından (notify_selfie_status → pg_net)
  // gelir; metinler app l10n notif_type_selfie_* anahtarlarıyla birebir aynı.
  selfie_approved: {
    ru: { t: 'Профиль подтверждён ✓', b: 'Теперь ты можешь участвовать в приглашениях' },
    tr: { t: 'Profil onaylandı ✓', b: 'Artık davetlere katılabilirsin' },
    en: { t: 'Profile verified ✓', b: 'You can now join invitations' },
  },
  selfie_rejected: {
    ru: { t: 'Фото отклонено', b: 'Пожалуйста, загрузи новое селфи' },
    tr: { t: 'Fotoğraf reddedildi', b: 'Lütfen yeni bir selfie yükle' },
    en: { t: 'Photo rejected', b: 'Please upload a new selfie' },
  },
}

// Preset red sebepleri — app l10n selfie_reason_* ile birebir aynı metinler
const SELFIE_REASONS: Record<string, Record<string, string>> = {
  face_unclear: { ru: 'Лицо видно нечётко', tr: 'Yüz net görünmüyor', en: 'Face not clearly visible' },
  too_far: { ru: 'Сделай селфи ближе', tr: 'Daha yakından çekmelisin', en: 'Take a closer selfie' },
  accessories: { ru: 'Очки/шапка/маска закрывают лицо', tr: 'Gözlük/şapka/maske yüzü kapatıyor', en: 'Glasses/hat/mask cover your face' },
  lighting: { ru: 'Мало света — сними при хорошем освещении', tr: 'Işık yetersiz — aydınlık yerde çek', en: 'Poor lighting — retake in good light' },
  mismatch: { ru: 'Не совпадает с фото профиля', tr: 'Profil fotoğraflarıyla eşleşmiyor', en: "Doesn't match your profile photos" },
  multiple_people: { ru: 'В кадре кто-то ещё — сделай селфи в одиночку', tr: 'Kadrajda başka biri var — tek başına çek', en: 'Someone else in frame — take it alone' },
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  try {
    const { user_id, title, body, data, template } = await req.json()
    if (!user_id || !title || !body) {
      return new Response(JSON.stringify({ error: 'user_id, title, body required' }), { status: 400, headers: CORS })
    }
    const db = new Client(DB_URL)
    await db.connect()
    const result = await db.queryObject<{ fcm_token: string; locale: string | null }>(
      'SELECT fcm_token, locale FROM users WHERE id = $1 LIMIT 1',
      [user_id]
    )

    // Bildirim tercihleri: tür kapalıysa VEYA sessiz saatler içindeyse push
    // atlanır. Uygulama-içi notifications kaydı ayrı oluşur (bu fn sadece
    // push gönderir), o yüzden atlamak listeyi etkilemez. Kayıt yoksa
    // varsayılan: tüm push açık, sessiz saatler kapalı.
    const notifType = (data?.type as string | undefined) ?? ''
    const typeToColumn: Record<string, string> = {
      new_application: 'push_new_application',
      selected: 'push_selected',
      new_message: 'push_message',
      match: 'push_match',
      // Owner'a seçim hatırlatması — başvuru push tercihine bağlı
      selection_reminder: 'push_new_application',
    }
    const col = typeToColumn[notifType]
    if (col) {
      const prefRes = await db.queryObject<Record<string, unknown>>(
        `SELECT ${col} AS enabled, quiet_hours_enabled, quiet_hours_start, quiet_hours_end
         FROM notification_preferences WHERE user_id = $1 LIMIT 1`,
        [user_id]
      )
      const pref = prefRes.rows[0]
      if (pref) {
        // Tür kapalı → atla
        if (pref.enabled === false) {
          await db.end()
          return new Response(JSON.stringify({ success: true, skipped: 'type_disabled' }), { headers: { ...CORS, 'Content-Type': 'application/json' } })
        }
        // Sessiz saatler içinde → atla (alıcının yerel saati; sunucu Europe/Moscow)
        if (pref.quiet_hours_enabled === true && pref.quiet_hours_start && pref.quiet_hours_end) {
          const now = new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Moscow' }))
          const cur = now.getHours() * 60 + now.getMinutes()
          const [sh, sm] = String(pref.quiet_hours_start).split(':').map(Number)
          const [eh, em] = String(pref.quiet_hours_end).split(':').map(Number)
          const start = sh * 60 + sm
          const end = eh * 60 + em
          // Gece aşan aralık (örn. 22:00–08:00) da doğru değerlendirilir
          const inQuiet = start <= end ? (cur >= start && cur < end) : (cur >= start || cur < end)
          if (inQuiet) {
            await db.end()
            return new Response(JSON.stringify({ success: true, skipped: 'quiet_hours' }), { headers: { ...CORS, 'Content-Type': 'application/json' } })
          }
        }
      }
    }

    await db.end()
    const fcmToken = result.rows[0]?.fcm_token
    if (!fcmToken) {
      return new Response(JSON.stringify({ error: 'no fcm_token' }), { status: 404, headers: CORS })
    }

    // Şablon: alıcının dilinde metin üret; istemci title/body yalnız fallback
    let finalTitle = title
    let finalBody = body
    const locale = result.rows[0]?.locale ?? 'ru'
    const tpl = TEMPLATES[notifType]?.[locale] ?? TEMPLATES[notifType]?.['ru']
    if (tpl) {
      const args = (template && typeof template === 'object') ? template : {}
      const fill = (s: string) => s
        .replace('{name}', String(args.name ?? ''))
        .replace('{count}', String(args.count ?? ''))
      finalTitle = fill(tpl.t).trim()
      finalBody = fill(tpl.b).trim()
      if (notifType === 'selfie_rejected') {
        const rt = SELFIE_REASONS[String(args.reason ?? '')]
        const reasonText = rt?.[locale] ?? rt?.['ru']
        if (reasonText) finalBody = `${reasonText} — ${finalBody}`
      }
    }

    const accessToken = await getFcmAccessToken()
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + accessToken,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: { title: finalTitle, body: finalBody },
            data: data ?? {},
            android: { priority: 'high' },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      }
    )
    const fcmData = await fcmRes.json()
    return new Response(JSON.stringify({ success: true, fcm: fcmData }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500, headers: CORS })
  }
})
