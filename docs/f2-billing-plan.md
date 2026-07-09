# F2 — Otomatik Yenilemeli Abonelik: Plan + Kararlar

> **TEK KAYNAK.** Session'lar arası referans dokümanı (legal-todos.md modeli).
> Onay: 09.07.2026 (Mustafa). Değişiklik ancak Mustafa onayıyla.
> **DURUM: Faz 2 TAMAMLANDI ✅ (09.07.2026)** — deploy + 2₽ UÇTAN UCA TEST GEÇTİ.
> Deploy: yedek `pre_f2_faz2_20260709_0919.sql.gz` + `/root/f2_rollback/`; unique-swap migration
> prod'da; 5 fn + _shared canlıda; smoke 8/8 temiz (sahte webhook idempotent-200 dahil), rollback
> gerekmedi. Deploy sırasında yakalanan fix: P9 kontrolü F1 log satırlarını saymasın (`9ba824ac`).
> **2₽ E2E (test aboneliği `ae83fb94`, kart •••• 4385):** create fn → pending_binding + consent_autopay
> (oferta_version kanıtı) → ödeme → webhook aktivasyonu (order 5761626, premium+30g, kart maskesi) →
> manuel charge → webhook Order-diff renewal (order 5761697, premium 07.09'a uzadı, charge_ok) →
> cancel (lokal, sade mesaj) → resume (ödemesiz) → status action tam veri → final cancel + kullanıcı
> free'ye sıfırlandı. **SMTP AÇILDI** (Timeweb talebi işlendi, 465 açık) — cancel_confirm e-postası
> CANLIDA GÖNDERİLDİ (email_ok:true). İade: 2×2₽ (5761626+5761697) kabinetten Mustafa'da.
> Testin banka tarafı kalıntısı: abonelik bankada Active (iptal yolu yok — S1); charge'ı yalnız biz
> tetikleriz, risksiz. NOT: compose daima `--env-file /root/supabase/docker/.env` ile.
> Faz 1 ✅ (oferta `docs/oferta-f2.html` onaylı, deploy Faz 4/6'da; UI metinleri §7).
> **Faz 2 ek bulgular (Mustafa doğrulaması):** renewal çeki de otomatik (Чек №626) — fiskalizasyon
> her çekimde kesin; Точка her ödemede kullanıcıya KENDİ onay mailini de atıyor (informer@tochka.com,
> «автопродление» ibaresiyle) — bizim bildirimleri tamamlayan bağımsız katman; kabinette «Подписки»
> ayrı sekme (payments-subscriptions) var, iki test aboneliği listeleniyor ama İPTAL BUTONU YOK (S1
> geçerli); Faz 2 iadeleri yapıldı (2×2₽ Возвращен).
> **Mail render fix (09.07.2026):** denomailer çıktısı Gmail'de bozuktu (ham QP gövde + ham encoded
> konu + boş attachment katmanı) → `_shared/billing-email.ts` ham SMTP + elle MIME'a geçirildi
> (tek text/plain utf-8, base64 CTE, RFC 2047 konu); 4 şablon test gönderimi yapıldı, Mustafa'nın
> görsel onayı bekleniyor. Yardımcı: `billing-email-test` fn (service-key korumalı, kalıcı test aracı).
> Mail render fix Mustafa tarafından Gmail'de DOĞRULANDI ✓ (İŞ 1 kapandı).
> **Faz 3 DEPLOY'DA ✅ (09.07.2026, DRY-RUN modda):** yedek `pre_f2_faz3_20260709_1028.sql.gz`;
> migration uygulandı (dry_run=TRUE + max_daily_attempts=1 [S3] + digest_email + tochka_jwt_expires_at
> [Точка JWT'sinde exp claim'i YOK — canlıda doğrulandı, P7 config tarihinden sayar: 363 gün] +
> grace-uyumlu downgrade + indeks); billing-cron + billing-status canlıda; crontab kuruldu
> (`25 7 * * * /root/bin/billing-cron.sh`, flock, log /var/log/billing-cron.log); smoke temiz
> (status never_ran→ok, auth'suz 403, elle dry-run koşusu: 0 aksiyon + digest event + heartbeat ok).
> İlk DRY-RUN digest maili Mustafa'nın Gmail teyidini bekliyor.
> **S5 UYGULANDI:** create-tochka-subscription artık `POST /acquiring/v1.0/subscriptions_with_receipt`
> (path alt çizgili — /with-receipt 501 verir!). Probe ile doğrulanan zorunlular: customerCode, amount,
> purpose, `Client.email`, `Items[].name/amount/quantity`. Çek DAİMA billing_email'e kesilir; 2₽ kanıtı
> Faz 6 provasında. **dry_run=false geçişi + Faz 6 canlı cron provası AYRI Mustafa onayı (değişmedi).**
> **FAZ 4 TAMAMLANDI ✅ (09.07.2026) — CANLI DEPLOY YAPILDI.** Web+oferta onaylı ekran turundan ve
> S24 cihaz kanıtından (6 screencap) geçti. Deploy: premium.html + oferta.html canlıda (yedekler:
> *.bak-f2-20260709-124921; yürürlük 9 июля 2026), `feature_flags.oferta_version={"v":"2026-07-09"}`,
> önizleme kaldırıldı, smoke temiz. App sürümü repo `c721bd8f` (cihazda doğrulandı; mağaza dağıtımı
> K/RuStore süreciyle). Turda düzeltilen 4 UI bug'ı: uppercase consent/e-posta etiketi, web i18n
> re-render, sheet butonu SafeArea, boş-durum boşluğu + boş-tarih kenar durumu; past_due'ya
> "Повторить оплату" (P8 ilk parça, _shared/billing-charge tek kaynak, S3 guard 20s/<2).
> NOT: l10n generated dosyalar elle güncellenmez (flutter build gen-l10n koşar). CI kuyruk takılırsa:
> cancel+rerun (attempt N, aynı run URL).
> **FAZ 6 PROVASI GEÇTİ ✅ (09.07.2026) — F2 KAPANDI, SİSTEM CANLI (dry_run=false).**
> Uçtan uca kanıt: with_receipt bağlama (e-posta banka sayfasında ÖNDEN DOLU geldi) → webhook
> aktivasyon → cron FAZ A çift kanal F2-1 bildirimi (push+mail, kullanıcı teyitli) → cron FAZ B
> GERÇEK 2₽ çekimi (order 5766290; cron pending_verify dedi, webhook yarışı kazanıp granted —
> çift katman tasarımı kanıtlandı) → renewal fiskal çeki otomatik → app'ten cancel/resume
> (4 kez üst üste, hepsi doğru işledi) → temizlik. **F2-1/F2-2/F2-3 üçü de kanıtlı.**
> Provada bulunan ve AYNI GÜN düzeltilen 3 şey: ① webhook renewal grant'inde başarı bildirimi
> eksikti (yarışta bildirim atlanıyordu) → webhook'a eklendi; ② iptal/devam sonrası snackbar
> onayı yoktu → eklendi (kullanıcı feedback'siz işlemi tekrarlıyordu — cihazda kanıtlandı);
> ③ tarife satırı sabit 1000₽ yazıyordu → gerçek price_paid.
> DERSLER: temp-şifre oturum üretme yöntemi GoTrue'da cihaz oturumunu düşürüyor (cihazda aktif
> oturum varken kullanma); kabinet iadeleri payments'a yansımıyor → P4 mutabakata "REFUNDED
> senkronu" kalemi eklendi. Bankada 3 test aboneliği Active kalır (fbaac9fb/ae83fb94/13792f60 —
> S1: kapatılamıyor, charge'ı yalnız biz tetikleriz, risksiz).
> İLK DOĞAL CANLI KOŞU: 10.07 10:25 MSK digest'i.
> **BACKLOG: SMS-OTP geçişi** — Mustafa SMS.ru'da авторизационный şablon başvurusu yapıyor
> (4 operatör). Onaylı şablon: «SoulChoice: код подтверждения %code%. Никому не сообщайте его.»
> Operatör onayları gelince send/verify-call-otp çağrıdan SMS'e geçirilecek (Mustafa onayıyla,
> kod şablonla %100 birebir olacak; şimdi kod değişikliği YOK).
> **iOS PREMIUM KEŞFİ — KARAR (09.07.2026): SEÇENEK B onaylı** (Sessiz Vitrin + e-posta):
> paywall iOS varyantı fiyatsız/linksiz (rozet+fayda listesi), onboarding'e opsiyonel e-posta,
> D+0 hoş geldin + D+2 premium tanıtım mailleri (fiyat/link e-postada serbest — Cameron v. Apple
> istisnası). **SMS kanalı kararı: Varyant 2 (in-app tetikleyicili, örn. limit anında ödeme
> linki SMS'i) KALICI HAYIR** — Sessiz Köprü ilkesi kanal bağımsız; e-posta serisi de limit
> anına BAĞLANMAZ (D+2 zamanlı kalır). **Varyant 1 (zaman bazlı tanıtım SMS'i) backlog'da,
> 3 koşullu:** ① operatör gönderici onayları ② hukukçu onaylı reklam-rıza metni canlıda ③ K
> onayı cebimizde — o gün bile e-posta ikamesi değil, e-postası olmayanlara ömür boyu 1 adet
> fallback. ФЗ-38: fiyat+link taşıyan SMS/e-posta reklamdır → onboarding'de ayrı, işaretsiz,
> loglanan pazarlama rızası şart (tek metin e-posta+SMS'i kapsar).

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
  ⚠️ Not (Faz 0): çek fiilen banka ödeme sayfasında müşterinin girdiği adrese gider —
  UI bankadaki adresle billing_email'in aynı olmasını telkin eder; pre-fill imkânı destek
  biletinde soruluyor (S5).
- **KARAR 4 — Yumuşak iptal (09.07.2026, Faz 0 sonrası):**
  - İptal = bizde `auto_renew=false` (çekim %100 durur — çekimi yalnız biz tetikliyoruz);
    kart bağı bankada kalır (API'de/kabinette iptal yok, Faz 0 bulgusu).
  - Tekrar abonelik: tek tık, YENİ ÖDEME YOK, çekim dönem sonunda devam eder.
  - İptal ekranı mesajı SADE: "Aboneliğin iptal edildi, premium X tarihine kadar aktif" —
    kart saklama lafı EKRANDA GEÇMEZ.
  - Kart saklama açıklaması YALNIZ oferta maddesinde: "İptal otomatik çekimi durdurur; ödeme
    bilgisi banka tarafında saklanır, tamamen silinmesi için support@soulchoice.app'e
    başvurulabilir."
  - Şeffaflık ekranda şöyle: abonelik ekranında kartın son 4 hanesi görünür; geri dönüşte
    "•••• XXXX ile devam et" butonu.
- **P-öncelikleri:** P1 (billing_events audit log), P2 (sabah digest), P3 (dead-man switch),
  P6 (billing_config fiyat/parametre tablosu), P7 (JWT süre alarmı), P9 (rate limit + tek pending
  abonelik kuralı) → **F2 çekirdeğinde**. P4 (günlük mutabakat) + P8 (dunning banner) → F2 sonrası
  hemen. P5 (ops panel sekmesi) + P10 (churn metrik view) → panel Adım 2 ile.

## 2. Точка recurring — doğrulanmış model (doküman + Faz 0 canlı testi)

- **Grafiksiz abonelik:** Create Subscription'da `recurring: true` → çekim takvimi yok; çekim
  **bizim** `POST /acquiring/v1.0/subscriptions/{operationId}/charge` çağrımızla (`amount` tek
  zorunlu alan). İptale kadar süresiz aylık model; tranche limiti yok. Kart-ONLY (СБП yok,
  komisyon %2,8; ödeme sayfasında yalnız "Банковской картой" çıktığı canlıda görüldü).
- Sözleşmemizde aktif, mevcut JWT yetiyor. Create zorunlu alanları: `customerCode`, `amount`,
  `purpose`; `merchantId`, `recurring`, `redirectUrl`, `failRedirectUrl` kabul ediliyor (test
  edildi). Yanıt: `operationId`, `paymentLink` (7 gün; sayfa açılınca ödemeye 1 saat),
  `consumerId`, `paymentLinkId`.
- Banka ödeme sayfası kendi **"Соглашаюсь с условиями автоплатежей"** onay kutusunu ve
  **"Сохранить карту"** işaretini gösteriyor; çek e-postası **"Куда отправить чек?"** alanıyla
  müşteriden alınıyor (Faz 0 ekran kanıtı).
- **ÇEKİM MODELİ (Faz 0 kritik bulgusu):** Charge YENİ OPERASYON YARATMAZ. Senkron
  `{"Data":{"result":true}}` döner; çekim aynı operasyonun `Order[]` dizisine
  `{orderId, type:"approval", amount, time}` satırı olarak eklenir ve `GET /payments/{opId}`'de
  ANINDA görünür. → Renewal eşleştirme birimi **orderId**'dir, operationId değil.
- **Webhook:** abonelik için ayrı event yok; bağlama VE her charge `acquiringInternetPayment`
  tetikler (Faz 0: 3 çekim = 3 webhook), hepsi AYNI operationId ile. Operasyon gövdesinde
  `CofToken: {tokenCardId, cardType, maskedPan}` var (hem webhook hem GET) → "son 4 hane" kaynağı.
- **İptal: API'DE VE KABİNETTE YOK (Faz 0).** Set Subscription Status grafiksiz aboneliği
  görmüyor (424 "Subscription not found" — query/body/recurring=true tüm varyantlarda; DELETE
  501). Kabinette abonelik detayı VAR ama iptal butonu YOK. → İptal mimarisi lokaldir (KARAR 4);
  banka tarafı prosedürü destek biletinde soruluyor.
- **Liste:** `GET /subscriptions` grafiksizleri ancak `?recurring=true` parametresiyle döner
  (P4 mutabakat cron'u bu parametreyi kullanacak).
- **Status:** `Preparing` (ödeme öncesi) → `Active`. Set Status enum'u yalnız `Cancelled`
  (grafikli abonelikler için; bizimkilere uygulanamıyor).
- **Fiskalizasyon (54-ФЗ): KUTUDAN TAM ÇÖZÜLÜ.** Bağlama ödemesi + HER charge için çek OTOMATİK
  kesiliyor (digitalKassaTochka/ЦИБ agent kassası), bağlamada girilen e-postaya gidiyor
  (Faz 0: 3 çekim = 3 çek maili). Ek kassa entegrasyonu GEREKMİYOR.
- **İade:** Abonelik çekimlerinin iadesi işlem bazında KABİNETTEN yapılıyor: abonelik detay
  sayfası → operasyona tıkla → "Вернуть платёж" (Faz 0'da 3×2₽ bu yolla iade edildi, "Возвращен").
  API'den abonelik iadesi yok. İadeler ANA hesaptan çıkar (Фонды tamponu).

### Точка destek bileti — CEVAPLANDI (09.07.2026, banka sohbeti)
| S | Soru | CEVAP |
|---|---|---|
| S1 | Grafiksiz abonelik iptali | **İptal edilemiyor; banka resmen "çekmemeniz yeterli" diyor** → KARAR 4 lokal iptal = bankanın önerdiği resmi yöntem. Kabinette buton olmaması da bundan. KAPANDI |
| S2 | Decline formatı | Açıklamalı hata kodu dönüyor; anlaşılmazsa bankaya sorulabilir → charge_fail event'ine ham yanıt yazma yaklaşımı doğru |
| S3 | Günlük deneme limiti | **Redde günde MAX 2 deneme** (başarılı çekimlerde limit yok) → `billing_config.max_daily_attempts=1` ile sabitlendi + cron'da attempt-önce-yaz + 20 saatlik sayaç çifte koruması |
| S4 | CofToken silme | Destek sohbetinden istenince siliniyor → operasyonel akış: kullanıcı support@'a yazar → biz banka sohbetinden sildiririz (oferta §2.1 zaten böyle) |
| S5 | Çek e-postası pre-fill | **Create Subscription WITH RECEIPT'te `Client.email` ZORUNLU** — banka "böyle yapın" diyor → geçiş analizi + öneri Faz 3 raporunda, Mustafa onayı bekliyor |

## 3. Mimari (onaylı; Faz 0 düzeltmeleri işlendi)

### 3a. DB
```
subscriptions (mevcut + yeni kolonlar)
  + tochka_subscription_id text UNIQUE   -- Create Subscription operationId
  + next_billing_at        timestamptz   -- premium_until ile senkron
  + renewal_notified_at    timestamptz   -- F2-1 kapısı (döngü başına)
  + notified_channels      text[]        -- ['push','email'] hangisi başarılı
  + retry_count            int default 0
  + grace_until            timestamptz
  + card_masked_pan        text          -- CofToken.maskedPan (maske, PAN DEĞİL)
  + card_type              text
  ~ status CHECK: active/cancelled/past_due/expired (+ pending_binding)
  -- KARAR 4: cancelled satır SİLİNMEZ; auto_renew=false + cancelled_at; reaktivasyon
  --          aynı satırda auto_renew=true'ya döner (tochka_subscription_id sabit)

users
  + billing_email text                   -- KARAR 3; bildirim adresi (çek adresi bankada girilir)

payments (mevcut + )  ⚠️ Faz 0 düzeltmesi
  + subscription_id uuid FK→subscriptions (nullable)
  + charge_type text CHECK: one_time/subscription_initial/subscription_renewal
  + order_id text                        -- Точка Order[].orderId (renewal'ın gerçek kimliği)
  ~ UNIQUE(operation_id) kaldırılır → UNIQUE(operation_id, order_id) (one_time'da order_id
    sentinel/'' — migration detayı; idempotency anahtarı artık bu çift)

billing_events (YENİ, append-only)         -- P1
billing_config (YENİ)                       -- P6
cron_heartbeat (YENİ)                       -- P3
```

### 3b. Akışlar
**Abone olma:** paywall/web'de e-posta adımı (zorunlu, KARAR 3; "çek için bankada aynı adresi
gir" telkini) → `create-tochka-subscription` edge fn → Точка `POST /subscriptions
{recurring:true, ...}` → subscriptions(pending_binding) + payments(pending,
subscription_initial, order_id='') → müşteri linkte kartla ilk 1000₽ öder (banka sayfası:
autoplatej onayı + kart kaydet + çek e-postası) → webhook: paid (ilk ödemenin operationId'si =
abonelik operationId; Order[0].orderId payments'a yazılır) → `premium_until =
greatest(now, mevcut)+30g`, status=active, auto_renew=true, `next_billing_at = premium_until`,
CofToken'dan kart maskesi. 7 günde ödenmezse cron pending_binding'i expire eder.

**Günlük billing-cron (07:25 UTC ≈ 10:25 MSK):**
- FAZ A bildirim: `next_billing_at ≤ now()+36s` + bu döngüde bildirilmemiş → push + e-posta;
  en az biri başarılı → `renewal_notified_at` + `notified_channels`. İkisi de başarısız →
  çekim kapısı KAPALI (süre dolunca free) — KARAR 3.
- FAZ B çekim (Faz 0 modeliyle): bildirim ≥24s önce şartıyla `charge {amount}` → senkron
  `result:true` → HEMEN `GET /payments/{opId}` → `Order[]`'daki YENİ orderId tespit →
  payments(paid, subscription_renewal, order_id) insert → premium_until+30g,
  next_billing_at+30g, retry=0, "yenilendi" push+mail. **Çekim onayı webhook'a muhtaç değil;**
  webhook ikincil teyit (aynı (operation_id, order_id) çifti — idempotent).
- FAZ C kurtarma: charge sonrası doğrulanamayan/yarım kalan döngüleri GET ile tamamla.
- Başarısızlık (KARAR 2): retry gün 0/+24s/+48s → past_due + grace (premium açık) → grace
  bitince auto_renew=false, expired → downgrade cron'u free'ye düşürür. Her aşamada bildirim.
- Sabit 30 günlük döngü; `≤ now()` taraması → kaçan koşu kendini onarır; koşu sonunda
  digest (P2) + heartbeat (P3).

**İptal (F2-2, KARAR 4 — yumuşak):** App Profil→Abonelik→İptal (≤2 tık + onay dialogu) ve web
/premium'da aynı → `manage-subscription` fn → SADECE lokal: auto_renew=false, status=cancelled,
cancelled_at (bankaya çağrı YOK — endpoint yok). Ekran: "Aboneliğin iptal edildi, premium X
tarihine kadar aktif" (sade; kart lafı yok). Dönem sonunda downgrade cron'u free'ye düşürür
(subscriptions→expired).
**Tekrar abonelik (dönem içinde):** "•••• XXXX ile devam et" → auto_renew=true, status=active —
ödeme YOK, çekim next_billing_at'te devam. Dönem bittiyse/expired ise: yeni bağlama akışı
(yeni Create Subscription + ödeme; süre greatest ile üste).

**Webhook genişletmesi:** operasyonda `CofToken` varsa abonelik operasyonudur → `Order[]` ile
lokal payments'ı karşılaştır, eksik orderId'leri işle; lokal pending_binding varsa aktive et;
hiç lokal kayıt yoksa 500/retry (orphan-insert YALNIZ CofToken'sız operasyonlara — mevcut
koddaki sahipsiz-paid tuzağının düzeltmesi).

**Hesap silme:** bankada iptal endpoint'i olmadığından: lokal cancel + billing_events kaydı;
CofToken silme prosedürü destek cevabına (S4) göre eklenecek (o zamana dek: silinen kullanıcı
için charge asla çağrılmaz — tek çekim tetikleyicisi biziz).

### 3c. Bildirimler (push = FCM `send-notification`; e-posta = Timeweb SMTP)
Çekim öncesi ≥24s (F2-1, servis mesajı — ФЗ-38 reklam onayı gerektirmez) • çekim başarılı •
çekim başarısız/past_due (+ app banner P8) • iptal onayı. Hepsi push+e-posta.
**DNS hazır (09.07.2026 doğrulandı):** MX timeweb, SPF `include:_spf.timeweb.ru`, DKIM seçici
`dkim`, DMARC `p=none` → kurulum gerekmez. **Eksik tek şey:** support@soulchoice.app SMTP
şifresi (Mustafa'dan, Faz 2 ön koşulu). Fiskal çekler bankadan otomatik gider (bizim işimiz değil).
Kanal "başarılı" tanımı: FCM 200+geçerli token; SMTP 250 accepted — billing_events'e yazılır.

### 3d. F1 ile birlikte yaşama
Mevcut tek-seferlik alıcılara dokunulmaz; "Otomatik yenileme kapalı — abonelik başlat" CTA'sı.
KARAR 1 gereği iki seçenek kalıcı yan yana. Çakışma yok: her ödeme premium_until'ü uzatır.

### 3e. Oferta (F2-3) — eklenecek madde başlıkları
Abonelik modeli+tutar+döngü • kartın bankada tokenize saklanması • çekim zamanı+ön bildirim
taahhüdü • iptal yöntemleri (app+web, ücretsiz/anlık) • iptal sonrası dönem sonuna kadar erişim •
**KARAR 4 maddesi:** "İptal otomatik çekimi durdurur; ödeme bilgisi banka tarafında saklanır,
tamamen silinmesi için support@soulchoice.app'e başvurulabilir" • başarısız çekim/grace
politikası • fiyat değişikliğinde ön bildirim+iptal hakkı • abonelik iade koşulları •
tek seferlik/abonelik ayrımı. Ödeme ekranlarında zorunlu consent checkbox (kabul zamanı+oferta
versiyonu DB'ye; bankanın kendi "условия автоплатежей" kutusu bizi İKAME ETMEZ, ikisi de durur).
Metin taslağı Faz 1'de onaya sunulur. **F2-1/F2-2/F2-3 üçü tamamlanmadan F2 kapanmaz.**

### 3f. iOS
Web /premium = iOS'un tam yönetim kapısı. App'te iOS: durum + sonraki çekim + İPTAL görünür
(iptal satın alma değil); abone ol/kart güncelle/"devam et" `paywall_mode` flag'iyle gizli,
web'e link YOK (anti-steering).

## 4. Fazlar

- **Faz 0 — Canlı doğrulama:** ✅ TAMAMLANDI 09.07.2026 (bulgular §6).
- **Faz 1 — Zemin:** migration (subscriptions kolonları, users.billing_email, billing_events,
  billing_config, payments order_id/charge_type/subscription_id + UNIQUE değişimi, CHECK'ler;
  prod'da `supabase_admin` + önce yedek) + oferta taslağı onaya (KARAR 4 diliyle) + consent
  checkbox. ~4 dosya.
- **Faz 2 — Edge fn'ler:** `create-tochka-subscription` (e-posta parametresi + P9 kuralları),
  `tochka-webhook` genişletme (CofToken/Order-diff modeli, orphan-fix), `manage-subscription`
  (durum + lokal iptal + "devam et" reaktivasyonu), `delete-account`a lokal cancel,
  `send-billing-email` helper + 4 RU şablon (SMTP creds ön koşul). ~5-6 dosya (repo+sunucu senkron).
- **Faz 3 — billing-cron:** FAZ A/B/C + digest + heartbeat + pg_cron (07:25 UTC) + P3 status
  endpoint + P7 JWT yaş kontrolü. F2-1 çift kanal kapısı koda gömülü. ~2 dosya.
- **Faz 4 — UI:** App Profil→Abonelik ekranı (plan/durum/sonraki çekim/kart son 4/geçmiş/2-tık
  sade iptal/"•••• XXXX ile devam et"; iOS kısıtlı mod) + paywall KARAR 1 düzeni + e-posta adımı
  + i18n; web premium.html yönetim bölümü + e-posta alanı. ~6-8 dosya.
- **Faz 5 — Ops:** P4 mutabakat (`?recurring=true` listesiyle), P8 dunning banner.
- **Faz 6 — Canlı geçiş:** 2₽ testinin F2 kod yoluyla tekrarı → gerçek fiyat → ilk hafta digest
  yakın izleme.

## 5. Faz 0 — test protokolü (arşiv)

Test aboneliği: operationId `fbaac9fb-d4ae-4631-a910-c8d1db5f6dfc`, paymentLinkId 8,
consumerId `50e1895f-...`, tokenCardId `179771492` (Mastercard •••• 4385). 3×2₽ çekildi
(orderId 5759323 bağlama / 5759423 charge / 5759455 charge — sonuncusu Claude dizilim hatası:
cancel 424 dönmüşken "red beklenir" charge'ı koşuldu), 3'ü de kabinetten iade edildi
("Возвращен"). Abonelik bankada Active kaldı (iptal yolu yok) — charge'ı yalnız biz
tetikleyebildiğimiz için risk yok; destek cevabına göre kapatılacak.
**Ders:** durum değiştiren her test adımı, önceki adımın doğrulamasına ŞARTLANIR.

## 6. Faz 0 bulguları (09.07.2026 — tamamı §2'ye işlendi)

1. İlk bağlama ödemesi = `amount` (ilk ay peşin) ✓
2. Charge: senkron `result:true`; yeni operasyon YOK → `Order[]`'a orderId satırı; GET anında
   güncel → **renewal kimliği orderId; payments şeması buna göre düzeltildi (§3a)** ✓
3. Fiskalizasyon: bağlama + her charge çeki OTOMATİK, bağlamada girilen e-postaya
   (digitalkassa; 3 çekim = 3 çek maili, Mustafa doğruladı) → ek kassa GEREKMİYOR ✓
4. Status: Preparing→Active; Set Status enum yalnız Cancelled ✓
5. **İptal API'de + kabinette YOK** (424/501; kabinette buton yok — Mustafa doğruladı) →
   KARAR 4 yumuşak iptal; S1/S4 destek biletinde ✓
6. redirectUrl çalışıyor (ödeme sonrası soulchoice.app'e dönüş görüldü) ✓
7. Her charge webhook tetikliyor (aynı operationId; 3 çağrı sayıldı); mevcut kod idempotent
   yutuyor → F2 webhook'u Order-diff modeliyle güncellenecek ✓
8. İade: kabinetten işlem bazında "Вернуть платёж" ✓ (API'den yok)
9. Kalan bilinmeyenler: S2 decline formatı + S3 retry limiti (destek bileti; kod savunmacı
   yazılır, Faz 1-3'ü bloklamaz)

## 7. Onaylı UI metin seti (09.07.2026 — Faz 4'te aynen; TR/DE bu anlamlardan çevrilir)

| Öğe | RU | EN |
|---|---|---|
| Consent checkbox | Соглашаюсь с условиями Оферты и даю согласие на автоматическое списание 1 000 ₽ каждые 30 дней до отмены подписки | I agree to the Offer terms and authorize automatic charges of 1,000 ₽ every 30 days until I cancel |
| İptal dialogu | Отменить подписку? / Автопродление будет отключено. Premium останется активным до {дата}. | Cancel subscription? / Auto-renewal will be turned off. Premium stays active until {date}. |
| Dialog butonları | Отменить подписку · Оставить | Cancel subscription · Keep it |
| İptal sonrası durum (SADE — KARAR 4) | Подписка отменена. Premium активен до {дата}. | Subscription cancelled. Premium is active until {date}. |
| Geri dönüş butonu | Продолжить с картой •••• {XXXX} | Continue with card •••• {XXXX} |
| Çekim öncesi push/mail (F2-1) | Подписка SoulChoice Premium продлится завтра — спишется 1 000 ₽. Управление — в профиле. | Your SoulChoice Premium renews tomorrow — 1,000 ₽ will be charged. Manage it in your profile. |
| Çekim başarılı | Подписка продлена. Premium активен до {дата}. | Subscription renewed. Premium is active until {date}. |
| Çekim başarısız | Не удалось продлить подписку — проверьте карту. Premium пока активен, мы повторим попытку. | We couldn't renew your subscription — please check your card. Premium is still active; we'll retry. |
