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
  // 26.07: davet sahibine eşleşme push'u (trg_notify_new_match) — "Eşleşmeler"
  // tercihi artık gerçek bir olayı yönetiyor; başvurana ikinci push atılmaz.
  match: {
    ru: { t: 'Совпадение! 🎉', b: 'Чат с {name} открыт' },
    tr: { t: 'Eşleşme! 🎉', b: '{name} ile sohbet açıldı' },
    en: { t: "It's a match! 🎉", b: 'Chat with {name} is open' },
  },
  selection_reminder: {
    ru: { t: 'Заявки ждут ✨', b: 'Заявок: {count} — загляни в них, окно выбора скоро закроется' },
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
  // Ödeme push'ları (24.07): webhook/billing-cron/manage-subscription çağırır.
  // Servis mesajları — bildirim tercihi kapısına bağlı değiller (ФЗ-38 uyumlu).
  // Metinler app l10n notif_type_premium_* ve billing-email şablonlarıyla hizalı.
  premium_activated: {
    ru: { t: 'Premium активен', b: 'Подписка оформлена — Premium активен до {date}' },
    tr: { t: 'Premium aktif', b: 'Aboneliğin başladı — Premium {date} tarihine kadar aktif' },
    en: { t: 'Premium active', b: 'Your subscription has started — Premium is active until {date}' },
  },
  premium_one_time: {
    ru: { t: 'Premium активен', b: 'Premium активен до {date}' },
    tr: { t: 'Premium aktif', b: 'Premium {date} tarihine kadar aktif' },
    en: { t: 'Premium active', b: 'Premium is active until {date}' },
  },
  premium_renewed: {
    ru: { t: 'SoulChoice Premium', b: 'Подписка продлена — Premium активен до {date}' },
    tr: { t: 'SoulChoice Premium', b: 'Aboneliğin yenilendi — Premium {date} tarihine kadar aktif' },
    en: { t: 'SoulChoice Premium', b: 'Subscription renewed — Premium is active until {date}' },
  },
  premium_renew_reminder: {
    ru: { t: 'SoulChoice Premium', b: 'Подписка продлится {date} — спишется {amount}. Управление — в профиле.' },
    tr: { t: 'SoulChoice Premium', b: 'Aboneliğin {date} tarihinde yenilenecek — {amount} çekilecek. Yönetim: profil.' },
    en: { t: 'SoulChoice Premium', b: 'Your subscription renews on {date} — {amount} will be charged. Manage it in your profile.' },
  },
  premium_renew_failed: {
    ru: { t: 'SoulChoice Premium', b: 'Не удалось продлить подписку — проверь карту. Premium пока активен, мы повторим попытку.' },
    tr: { t: 'SoulChoice Premium', b: 'Abonelik yenilenemedi — kartını kontrol et. Premium şimdilik aktif, tekrar deneyeceğiz.' },
    en: { t: 'SoulChoice Premium', b: "Couldn't renew your subscription — check your card. Premium is still active; we'll retry." },
  },
  premium_resumed: {
    ru: { t: 'SoulChoice Premium', b: 'Автопродление снова включено — Premium активен до {date}' },
    tr: { t: 'SoulChoice Premium', b: 'Otomatik yenileme yeniden açıldı — Premium {date} tarihine kadar aktif' },
    en: { t: 'SoulChoice Premium', b: 'Auto-renewal is back on — Premium is active until {date}' },
  },
  premium_cancelled: {
    ru: { t: 'Подписка отменена', b: 'Premium активен до {date}' },
    tr: { t: 'Abonelik iptal edildi', b: 'Premium {date} tarihine kadar aktif' },
    en: { t: 'Subscription cancelled', b: 'Premium is active until {date}' },
  },
  premium_expired: {
    ru: { t: 'SoulChoice Premium', b: 'Подписка завершилась, Premium отключён. Возобновить — в профиле.' },
    tr: { t: 'SoulChoice Premium', b: 'Aboneliğin sona erdi, Premium kapandı. Profilden yeniden başlatabilirsin.' },
    en: { t: 'SoulChoice Premium', b: 'Your subscription has ended and Premium is off. Restart it from your profile.' },
  },
  // 24.07 C1: nötr askı bildirimi (DB trigger notify_suspension → pg_net).
  // Gerekçe bilinçli olarak yazılmıyor — o tasarım post-launch karar.
  account_suspended: {
    ru: { t: 'SoulChoice', b: 'Аккаунт приостановлен — подробности: support@soulchoice.app' },
    tr: { t: 'SoulChoice', b: 'Hesabın askıya alındı — detay: support@soulchoice.app' },
    en: { t: 'SoulChoice', b: 'Your account has been suspended — details: support@soulchoice.app' },
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

const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  try {
    // 31.07 GÜVENLİK: bu uç yalnız SUNUCU tarafından çağrılır (DB trigger'ları +
    // billing/webhook fonksiyonları). Kong'da JWT doğrulaması kapalı olduğu için
    // uç anahtarsız çağrılabiliyordu → herkes istediği kullanıcıya istediği
    // metinle push atabiliyordu (kimlik avı). Artık service key şartı var.
    const auth = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
    if (!SERVICE_KEY || auth !== SERVICE_KEY) {
      return new Response(JSON.stringify({ error: 'unauthorized' }), {
        status: 401, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }
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
    // Servis mesajları (para/hesap durumu — ФЗ-38): tercih ve sessiz-saat
    // kapısına TAKILMAZ. Geri kalan her şey (selfie dahil) sessiz saatlere
    // uyar (31.07 denetimi: selfie push'u gece 03:00'te gidebiliyordu).
    const isService = notifType.startsWith('premium_') || notifType === 'account_suspended'
    const col = typeToColumn[notifType]
    if (col || !isService) {
      const prefRes = await db.queryObject<Record<string, unknown>>(
        `SELECT ${col ? `${col} AS enabled,` : 'true AS enabled,'} quiet_hours_enabled, quiet_hours_start, quiet_hours_end
         FROM notification_preferences WHERE user_id = $1 LIMIT 1`,
        [user_id]
      )
      const pref = prefRes.rows[0]
      if (pref) {
        // Tür kapalı → atla (yalnız toggle'ı olan türler)
        if (col && pref.enabled === false) {
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
    // 26.07 çift-push koruması (31.07: artık TÜM türler için — selfie/premium
    // çift gidebiliyordu): 8 sn pencerede aynı (alıcı, tip, ref) ikinci kez
    // gönderilmez. push_log yoksa/hata olursa dedupe atlanır — push göndermek
    // dedupe'tan her zaman önceliklidir.
    try {
      const dedupRef = String(data?.match_id ?? data?.invitation_id ?? '')
      const dup = await db.queryObject(
        "SELECT 1 FROM push_log WHERE user_id = $1 AND type = $2 AND ref = $3 AND sent_at > now() - interval '8 seconds' LIMIT 1",
        [user_id, notifType, dedupRef]
      )
      if (dup.rows.length > 0) {
        await db.end()
        return new Response(JSON.stringify({ success: true, skipped: 'duplicate' }), { headers: { ...CORS, 'Content-Type': 'application/json' } })
      }
      await db.queryObject(
        'INSERT INTO push_log(user_id, type, ref) VALUES ($1, $2, $3)',
        [user_id, notifType, dedupRef]
      )
    } catch (_) { /* dedupe altyapısı henüz yoksa push yine gitsin */ }

    // iOS rozet: okunmamış in-app bildirim sayısı (notifications insert'i bu
    // fonksiyondan ÖNCE yapıldığı için mevcut olay sayıma dahil). Süs — hata
    // push'u engellemez.
    let unread = 0
    try {
      const u = await db.queryObject<{ c: number }>(
        'SELECT count(*)::int AS c FROM notifications WHERE user_id = $1 AND read_at IS NULL',
        [user_id]
      )
      unread = Number(u.rows[0]?.c ?? 0)
    } catch (_) { /* rozet süs */ }

    await db.end()
    const fcmToken = result.rows[0]?.fcm_token
    if (!fcmToken) {
      return new Response(JSON.stringify({ error: 'no fcm_token' }), { status: 404, headers: CORS })
    }

    // 31.07 (Mustafa onayı) — çoklu bildirim düzeni:
    //  • Collapse: aynı sohbet/ilan için TEK bildirim — yenisi eskisini günceller
    //    (Android tag + apns-collapse-id). Anahtar sözleşmesi "<tip>:<ref>" —
    //    app'teki NotificationCleaner ile birebir aynı.
    //  • Android kanalı: sohbet mesajları "messages", geri kalan "general"
    //    (kanal yoksa FCM varsayılan kanala düşer — eski build güvenli).
    const collapseRef = String(data?.match_id ?? data?.invitation_id ?? '')
    const collapseKey = collapseRef ? `${notifType}:${collapseRef}` : ''
    const channelId = notifType === 'new_message' ? 'messages' : 'general'

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
        .replace('{date}', String(args.date ?? ''))
        .replace('{amount}', String(args.amount ?? ''))
      finalTitle = fill(tpl.t).trim()
      finalBody = fill(tpl.b).trim()
      // RU fiil çekimi aktörün cinsiyetine göre (istemci template.gender yollar;
      // eski istemciler yollamazsa nötr "(а)" hali kalır) — 16.07
      if (notifType === 'selected') {
        const g = String(args.gender ?? '')
        const verb = g === 'female' ? 'выбрала' : g === 'male' ? 'выбрал' : 'выбрал(а)'
        finalBody = finalBody.replace('выбрал(а)', verb)
      }
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
            android: {
              priority: 'high',
              notification: {
                channel_id: channelId,
                ...(collapseKey ? { tag: collapseKey } : {}),
              },
            },
            apns: {
              ...(collapseKey ? { headers: { 'apns-collapse-id': collapseKey } } : {}),
              payload: {
                aps: {
                  sound: 'default',
                  badge: unread,
                  ...(collapseKey ? { 'thread-id': collapseKey } : {}),
                },
              },
            },
          },
        }),
      }
    )
    const fcmData = await fcmRes.json()
    // 25.07: FCM hatası sessiz yutulmaz (E2E'de ölü token 2 gün fark edilmedi).
    // UNREGISTERED/404 = token'ın ait olduğu kurulum artık yok (app silinmiş /
    // yeniden kurulmuş) → DB'den temizle ki durum görünür olsun; alıcı app'i
    // bir sonraki açışında main.dart savePushToken taze token'ı yazar.
    if (!fcmRes.ok) {
      const errCode = fcmData?.error?.details?.find?.((d: { errorCode?: string }) => d?.errorCode)?.errorCode ?? fcmData?.error?.status ?? ''
      console.error(`send-notification FCM FAIL user=${user_id} type=${notifType} http=${fcmRes.status} code=${errCode}`)
      if (fcmRes.status === 404 || errCode === 'UNREGISTERED') {
        try {
          const db2 = new Client(DB_URL)
          await db2.connect()
          await db2.queryObject('UPDATE users SET fcm_token = NULL WHERE id = $1 AND fcm_token = $2', [user_id, fcmToken])
          await db2.end()
        } catch (_) { /* temizlik başarısız olsa da push zaten gitmedi; log yeterli */ }
      }
      return new Response(JSON.stringify({ success: false, fcm: fcmData }), {
        headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }
    return new Response(JSON.stringify({ success: true, fcm: fcmData }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500, headers: CORS })
  }
})
