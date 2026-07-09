# F2 — Otomatik Yenilemeli Abonelik: Plan + Kararlar

> **TEK KAYNAK.** Session'lar arası referans dokümanı (legal-todos.md modeli).
> Onay: 09.07.2026 (Mustafa). Değişiklik ancak Mustafa onayıyla.
> **DURUM: Faz 0 sürüyor** — 2₽ canlı abonelik testi. Faz 1'e Mustafa onayıyla geçilir.

## 0. Genel ilke — inisiyatif (Mustafa, 09.07.2026)

Mustafa'nın kararları hedefi tanımlar, uygulama detayında kalıp değildir. Teknik uygulamada
daha iyi yol görülürse uygulanır ve sapma gerekçesiyle raporlanır. İki istisna:
1. Ürün/para/kullanıcı-deneyimi kararları değiştirilmez — farklı görüş uygulamadan ÖNCE sorulur.
2. ASLA ONAYSIZ YAZMA: hiçbir kod/migration/deploy onaysız yapılmaz.

## 1. Kullanıcı kararları (09.07.2026)

- **KARAR 1 — Ödeme seçenekleri:** İki seçenek yan yana. Varsayılan/büyük: "Abonelik — 1000₽/ay,
  otomatik yenilenir" (kart). Altta sade: "Tek seferlik 30 gün" (СБП/kart, F1 akışı korunur).
  İkisi de `premium_until` uzatır; `auto_renew` yalnız abonelikle true.
- **KARAR 2 — Başarısız çekim/grace:** 3 deneme (gün 0, +24s, +48s) + grace; grace boyunca
  premium AÇIK kalır, sonra free. Her aşamada kullanıcıya bildirim.
- **KARAR 3 — E-posta modeli:** Abonelik başlatırken **e-posta ZORUNLU alan** (yalnız abonelere;
  normal kayıt akışına dokunulmaz). Saklama: `users.billing_email` (teknik karar: kullanıcıya ait,
  yeniden abonelikte kaybolmaz, çek adresi olarak tekildir). Çekim öncesi bildirim **hem push hem
  e-posta**; **en az biri başarıyla gönderilmeden çekim yapılmaz**; ikisi de gönderilemezse çekim
  yok, süre dolunca free. Gönderim: support@soulchoice.app / Timeweb SMTP (işlem mailleri:
  hatırlatma, başarılı/başarısız, iptal onayı). Aynı e-posta fiskal çek (54-ФЗ) adresi.
- **P-öncelikleri:** P1 (billing_events audit log), P2 (sabah digest), P3 (dead-man switch),
  P6 (billing_config fiyat/parametre tablosu), P7 (JWT süre alarmı), P9 (rate limit + tek pending
  abonelik kuralı) → **F2 çekirdeğinde**. P4 (günlük mutabakat) + P8 (dunning banner) → F2 sonrası
  hemen. P5 (ops panel sekmesi) + P10 (churn metrik view) → panel Adım 2 ile.

## 2. Точка recurring — doğrulanmış bulgular (09.07.2026)

- **Grafiksiz abonelik** (changelog 18.04.2025): Create Subscription'da `recurring: true` →
  çekim takvimi yok; çekim **bizim** `POST /acquiring/v1.0/subscriptions/{operationId}/charge`
  çağrımızla olur (zorunlu alan sadece `amount`, canlı validasyon probuyla doğrulandı) →
  iptale kadar süresiz aylık model kurulabilir, tranche limiti yok.
- Abonelik API'si sözleşmemizde **aktif**: `GET /subscriptions?customerCode=305892846` → 200
  (mevcut JWT ile; ek aktivasyon gerekmedi).
- Create Subscription zorunlu alanları (validasyon probu): `customerCode`, `amount`, `purpose`.
- **Kart-ONLY** (СБП abonelikte yok → komisyon %2,8). Bağlama linki 7 gün geçerli; linke giren
  müşterinin ödemeye 1 saati var. 3DS/onay ilk ödemede banka sayfasında.
- Webhook'ta abonelik için ayrı event YOK; abonelik ödemeleri de `acquiringInternetPayment`.
  06.07.2026'dan beri kartlı ödemede `maskedPan`, `cardType`, `tokenCardId` alanları geliyor
  (yönetim ekranındaki "son 4 hane" kaynağı).
- İptal: `POST /subscriptions/{operationId}/status` (zorunlu alan `status`; dokümana göre
  Cancelled yapılabiliyor). Abonelik ödemesinin iadesi **sadece internet bankadan** (API yok).
- Kart verisi/token bizde durmaz — Точка'da. Biz sadece `operationId` + maske saklarız (PCI yükü yok).

### Faz 0'da netleşecekler (doğrulanamayanlar)
| # | Soru | Faz 0 adımı |
|---|---|---|
| 1 | İlk bağlama ödemesi `amount` kadar mı (ilk ay peşin mi)? | Adım 3 |
| 2 | Charge hata gövdesi + aynı gün retry kuralları | Adım 7 (+ gerekirse banka desteği) |
| 3 | **Fiskal çek:** bağlamada ve charge'da çek kesiliyor mu, müşteri e-postası verilebiliyor mu? | Adım 3+7 |
| 4 | Abonelik status enum değerleri | Adım 2+6 |
| 5 | Un-cancel mümkün mü / kart değiştirme mekanizması | Adım 9 |
| 6 | Create'te `redirectUrl`/`paymentLinkId` kabul ediliyor mu | Adım 1 |
| 7 | Charge webhook timing + `GET /payments/{opId}` ile sorgulanabilirlik | Adım 7 |

## 3. Mimari (onaylı)

### 3a. DB
```
subscriptions (mevcut + yeni kolonlar)
  + tochka_subscription_id text UNIQUE   -- Create Subscription operationId
  + next_billing_at        timestamptz   -- premium_until ile senkron
  + renewal_notified_at    timestamptz   -- F2-1 kapısı (döngü başına)
  + notified_channels      text[]        -- ['push','email'] hangisi başarılı
  + retry_count            int default 0
  + grace_until            timestamptz
  + card_masked_pan        text          -- webhook maskedPan (maske, PAN DEĞİL)
  + card_type              text
  ~ status CHECK: active/cancelled/past_due/expired (+ pending_binding)

users
  + billing_email text                   -- KARAR 3; çek + bildirim adresi

payments (mevcut + )
  + subscription_id uuid FK→subscriptions (nullable)
  + charge_type text CHECK: one_time/subscription_initial/subscription_renewal

billing_events (YENİ, append-only)         -- P1
  id, subscription_id, user_id, event, detail jsonb, created_at

billing_config (YENİ)                       -- P6
  price_rub, grace_hours, retry_schedule, ...

cron_heartbeat (YENİ)                       -- P3
```

### 3b. Akışlar
**Abone olma:** paywall/web'de e-posta adımı (zorunlu, KARAR 3) → `create-tochka-subscription`
edge fn → Точка `POST /subscriptions {recurring:true, amount, purpose, ...}` →
subscriptions(pending_binding) + payments(pending, subscription_initial) → müşteri linkte kartla
ilk 1000₽ öder → webhook: paid → `premium_until = greatest(now, mevcut)+30g`, status=active,
auto_renew=true, `next_billing_at = premium_until`, kart maskesi kaydedilir.
7 günde ödenmezse cron pending_binding'i expire eder.

**Günlük billing-cron (07:25 UTC ≈ 10:25 MSK):**
- FAZ A bildirim: `next_billing_at ≤ now()+36s` + bu döngüde bildirilmemiş → push + e-posta;
  en az biri başarılı → `renewal_notified_at` + `notified_channels`. İkisi de başarısız →
  çekim kapısı KAPALI (süre dolunca free) — KARAR 3.
- FAZ B çekim: `next_billing_at ≤ now()` VE bildirim ≥24s önce → `charge {amount}` →
  payments(pending, subscription_renewal) → sonuç WEBHOOK'tan: paid → premium_until+30g,
  next_billing_at+30g, retry=0, "yenilendi" push+mail.
- FAZ C kurtarma: 15+ dk pending renewal'ları `GET /payments/{opId}` ile poll et.
- Başarısızlık (KARAR 2): retry 0/+24s/+48s → past_due + grace (premium açık) → grace bitince
  auto_renew=false, expired, downgrade cron'u free'ye düşürür. Her aşamada bildirim.
- Sabit 30 günlük döngü (takvim ayı değil) → 29-31 sorunu yok. `≤ now()` taraması → kaçan cron
  koşusu kendini onarır. Koşu sonunda digest (P2) + heartbeat (P3).

**İptal (F2-2):** App Profil→Abonelik→İptal (≤2 tık + onay dialogu) ve web /premium'da aynı →
`manage-subscription` fn → Точка Set Status Cancelled → auto_renew=false, cancelled_at →
"X tarihine kadar premium" gösterilir; dönem sonunda mevcut downgrade cron'u düşürür.
**Tekrar abonelik:** yeni bağlama ödemesi; süre `greatest(now, premium_until)+30g` ÜSTE eklenir
(ekranda açıkça yazılır). (Faz 0 Adım 9 un-cancel'ı mümkün gösterirse akıcılaştırma önerilir.)

**Hesap silme:** `delete-account` fn'e Точка iptal adımı EKLENECEK (CASCADE'den önce) —
yoksa silinmiş kullanıcının kartından çekim sürer.

**Webhook orphan-fix (mevcut kod tuzağı):** webhook bilinmeyen-APPROVED operasyonu kullanıcısız
`paid` yazıyor; renewal yarışında abonelik uzamaz. Fix: operasyonda `tokenCardId` varsa ve lokal
pending yoksa 500 dön (Точка retry) — orphan-insert sadece token'sız operasyonlara.

### 3c. Bildirimler (push = FCM `send-notification`; e-posta = Timeweb SMTP)
Çekim öncesi ≥24s (F2-1, servis mesajı — ФЗ-38 reklam onayı gerektirmez) • çekim başarılı •
çekim başarısız/past_due (+ app banner P8) • iptal onayı. Hepsi push+e-posta.
**DNS hazır (09.07.2026 doğrulandı):** MX timeweb, SPF `include:_spf.timeweb.ru`, DKIM seçici
`dkim` kayıtlı, DMARC `p=none` → Mail.ru/Yandex teslimat zemini var, kurulum gerekmez.
**Eksik tek şey:** support@soulchoice.app SMTP şifresi (Mustafa'dan, Faz 2 ön koşulu).
Kanal "başarılı" tanımı: FCM 200+geçerli token; SMTP 250 accepted — billing_events'e yazılır.

### 3d. F1 ile birlikte yaşama
Mevcut tek-seferlik alıcılara dokunulmaz; "Otomatik yenileme kapalı — abonelik başlat" CTA'sı.
KARAR 1 gereği iki seçenek kalıcı yan yana. Çakışma yok: her ödeme premium_until'ü uzatır.

### 3e. Oferta (F2-3) — eklenecek madde başlıkları
Abonelik modeli+tutar+döngü • kartın bankada tokenize saklanması • çekim zamanı+ön bildirim
taahhüdü • iptal yöntemleri (app+web, ücretsiz/anlık) • iptal sonrası dönem sonuna kadar erişim •
başarısız çekim/grace politikası • fiyat değişikliğinde ön bildirim+iptal hakkı • abonelik
iade koşulları • tek seferlik/abonelik ayrımı. Ödeme ekranlarında zorunlu consent checkbox
(kabul zamanı+oferta versiyonu DB'ye). Metin taslağı Faz 1'de onaya sunulur.
**F2-1/F2-2/F2-3 üçü tamamlanmadan F2 kapanmaz** (Mustafa şartı 08.07.2026).

### 3f. iOS
Web /premium = iOS'un tam yönetim kapısı. App'te iOS: durum + sonraki çekim + İPTAL görünür
(iptal satın alma değil); abone ol/kart güncelle `paywall_mode` flag'iyle gizli, web'e link YOK
(anti-steering).

## 4. Fazlar

- **Faz 0 — Canlı doğrulama (kod yok):** aşağıdaki checklist. ✅ başlandı 09.07.2026.
- **Faz 1 — Zemin:** migration (subscriptions kolonları, users.billing_email, billing_events,
  billing_config, payments kolonları, CHECK'ler; prod'da `supabase_admin` + önce yedek) +
  oferta taslağı onaya + consent checkbox. ~4 dosya.
- **Faz 2 — Edge fn'ler:** `create-tochka-subscription` (yeni; e-posta parametresi + P9 kuralları),
  `tochka-webhook` genişletme (abonelik aktivasyonu, renewal, orphan-fix), `manage-subscription`
  (durum+iptal), `delete-account`a iptal adımı, `send-billing-email` helper + 4 RU şablon
  (SMTP creds ön koşul). ~5-6 dosya (repo+sunucu senkron).
- **Faz 3 — billing-cron:** FAZ A/B/C + digest + heartbeat + pg_cron kaydı (07:25 UTC) +
  P3 status endpoint + P7 JWT yaş kontrolü. F2-1 çift kanal kapısı burada koda gömülü. ~2 dosya.
- **Faz 4 — UI:** App Profil→Abonelik ekranı (plan/durum/sonraki çekim/kart son 4/geçmiş/2-tık
  iptal; iOS kısıtlı mod) + paywall'a KARAR 1 düzeni + e-posta adımı + i18n; web premium.html
  yönetim bölümü + e-posta alanı (varsa billing_email ön dolu). ~6-8 dosya.
- **Faz 5 — Ops:** P4 mutabakat cron'u, P8 dunning banner (panel P5/P10 panel Adım 2 ile).
- **Faz 6 — Canlı geçiş:** 2₽ testinin F2 kod yoluyla tekrarı → gerçek fiyat → ilk hafta digest
  yakın izleme.

## 5. Faz 0 — 2₽ canlı test checklist

Komutlar sunucuda (`ssh root@89.169.1.127`), env: `source <(grep -E "^TOCHKA_" /root/supabase/docker/.env | sed "s/^/export /")`. Token repo'ya YAZILMAZ.

1. **Create** (Claude): `POST /uapi/acquiring/v1.0/subscriptions` body
   `{"Data":{"customerCode":$CC,"merchantId":$MID,"amount":"2.00","purpose":"Тест подписки SoulChoice Premium","recurring":true,"redirectUrl":"https://soulchoice.app/?sub=ok","failRedirectUrl":"https://soulchoice.app/?sub=fail"}}`
   → operationId + bağlama linki. (redirectUrl reddedilirse minimal gövdeyle tekrar → bulgu #6)
2. **Status (ödeme öncesi)** (Claude): `GET /subscriptions/{opId}/status` → başlangıç enum'u (#4)
3. **Ödeme** (Mustafa): linki aç (açınca 1 saat!), KARTLA 2₽ öde; sayfa e-posta soruyorsa gir →
   çek nereye düştü not et (#1 #3)
4. **Webhook izleme** (Claude): `docker logs supabase-edge-functions` → maskedPan/tokenCardId
   alanları geldi mi; payments'e orphan satır düştü mü (beklenen davranış, bulgu olarak kaydedilir)
5. **Status (ödeme sonrası)** (Claude): Active mi (#4)
6. **Enum probu** (Claude): Set Status'a kasıtlı geçersiz değer → 400 hatası izinli değerleri
   listeler (#4) — hiçbir şey değiştirmez
7. **Charge 2₽** (Claude): `POST /subscriptions/{opId}/charge {"Data":{"amount":"2.00"}}` →
   webhook timing (#7), `GET /payments/{chargeOpId}` (#7), çek e-postaya kesildi mi (#3);
   hata olursa gövdeyi kaydet (#2)
8. **Cancel** (Claude): Set Status Cancelled → status doğrula → charge tekrar dene (reddetmeli)
9. **Un-cancel probu** (Claude): Set Status'la tekrar aktif etmeyi dene (#5)
10. **İade** (Mustafa): internet bankadan 2×2₽ iade (⚠️ Фонды: ana hesapta tampon)

### Faz 0 bulguları
_(test sonrası doldurulacak)_
