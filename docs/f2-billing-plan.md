# F2 — Otomatik Yenilemeli Abonelik: Plan + Kararlar

> **TEK KAYNAK.** Session'lar arası referans dokümanı (legal-todos.md modeli).
> Onay: 09.07.2026 (Mustafa). Değişiklik ancak Mustafa onayıyla.
> **DURUM: Faz 1 SÜRÜYOR (09.07.2026)** — migration taslağı repo'da
> (`supabase/migrations/20260709_f2_subscriptions.sql`), PROD'A UYGULANMADI (ayrı onay + yedek
> şart). Oferta + UI metinleri onaya sunuldu. Точка destek bileti Mustafa'da (S1-S5).
> Faz 0 bulguları §6. NOT: payments UNIQUE(operation_id)→(operation_id, order_id) geçişi
> bilinçli olarak Faz 2'ye ertelendi (canlı webhook'un `on conflict (operation_id)` yolu
> kırılmasın; webhook deploy'uyla atomik yapılacak).

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

### Açık kalanlar → Точка destek bileti (Mustafa gönderecek)
| S | Soru | Durum |
|---|---|---|
| S1 | Grafiksiz aboneliğin API'den iptali/deaktivasyonu (planlanıyor mu?) | Cevap bekliyor |
| S2 | Charge decline'ında dönen HTTP kod + gövde formatı (yetersiz bakiye vs kart kapalı) | Cevap bekliyor; kod her biçimi güvenli işleyecek |
| S3 | Aynı abonelikte günlük Charge deneme limiti / anti-fraud kısıtı | Cevap bekliyor |
| S4 | CofToken'ın (kart bağı) müşteri talebiyle tamamen silinme prosedürü | Cevap bekliyor |
| S5 | Create Subscription'da çek e-postasını pre-fill etme alanı var mı | Cevap bekliyor (Claude önerisi) |

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
