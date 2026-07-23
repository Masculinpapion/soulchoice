# UX Yolculuk × Kanal Denetimi — TEK KAYNAK (ilk tam tarama: 24.07.2026)

Amaç: her kullanıcı yolculuğu adımında geri bildirim kanallarının (ekran durumu / push /
zil kaydı / e-posta / i18n) eksiksizliği. Kalıcı refleks: product-logic **§13.1 soru 9** —
davranış değiştiren her commit bu matrisi günceller. Tarama yöntemi: 3 paralel kod denetimi
(app yüzeyi, sunucu olay×kanal, i18n/ham metin), bulgular tek tek koddan doğrulandı.

## A. 24.07'de DÜZELTİLDİ (commit `e292e45` + `e51e379`)

| # | Boşluk | Düzeltme |
|---|--------|----------|
| 1 | İlk satın alma + tek-seferlik ödemede push RU-only, 8 ödeme push'unun tamamı ham RU metin | 7 şablon tipi (`premium_*`), alıcının `users.locale`'inde ru/tr/en |
| 2 | Chat mesaj yüklemesi hatada sonsuz spinner | hata durumu + Tekrar dene |
| 3 | Sahibin Seç/Reddet aksiyonları sessiz başarısızlık | snackbar (guard token'ları dahil) |
| 4 | Engelleme başarısızsa "engellendi" gibi çıkıp gidiyordu | hata snackbar'ı + ekranda kalış |
| 5 | Premium zil bildirimi kayıtsız `/profile` rotasına gidiyordu (Page not found) | `/subscription` |
| 6 | Abonelik ekranı ağ hatasını "abonelik yok" olarak gösteriyordu | hata durumu + Tekrar dene |
| 7 | Süresi dolmuş ilanda aktif görünen ölü "Başvur" butonu | pasif "Süresi doldu" |
| 8 | 15 ekranda ham `e.toString()` kullanıcıya sızıyordu (§13.1/6 ihlali) | lokalize `error_generic` (guard token yolu korunarak) |
| 9 | Billing e-postaları tamamen RU-only | işlemsel 6 tür ru/tr/en (`users.locale`) |
| 10 | Grace bitişi = premium sessizce kapanıyordu (en yüksek churn riski) | `premium_expired` push + e-posta (billing-cron FAZ C) |
| 11 | F1 tek-seferlik ödemede e-posta yoktu | `purchase_success` paritesi |
| 12 | OTP ekranında ham exception metni | lokalize hata |

## B. HAZIR ama beklemede

- **Zil ekranı `premium_activated` kaydı:** app desteği 610+ build'lerde; sunucu insert'i
  `PREMIUM_BELL_NOTIF` flag'i arkasında KAPALI. Build'ler 3 kanala dağıtılınca açılacak.
  O gün ayrıca yenileme/iptal/başarısızlık olayları da zile bağlanmalı (şu an yalnız initial).

## C. ÜRÜN KARARI BEKLEYEN (Mustafa) — dokunulmadı

| # | Konu | Not |
|---|------|-----|
| C1 | Ban / no-show askısı bildirimsiz | Kullanıcı ancak engellenince öğreniyor (suspended ekranı var). Push/e-posta + gerekçe/itiraz yolu eklensin mi? Şeffaflık/152-ФЗ boyutu var. |
| C2 | Reddedilen başvurana push yok (zil kaydı VAR) | product-logic §118 "bilinçli sessizlik" ile zil trigger'ı çelişiyor — hangisi doğru? (Push'suz zil mevcut davranış.) |
| C3 | Hesap silme onay e-postası yok | GDPR iyi pratiği "silindi" teyidi ister; e-posta adresi her kullanıcıda yok (yalnız billing_email). |
| C4 | Sosyal push'lar istemci-tetikli (gönderen ölürse push düşmez; zil sağlam) | Kalıcı çözüm: selfie'deki gibi pg_net trigger'a taşımak. Launch öncesi riskli; post-launch backlog önerisi. |
| C5 | SQL cron'daki genel premium düşüşü (F1/tekil `premium_until` bitişi) bildirimsiz | Abonelik grace-sonu 24.07'de kapandı; kalan durum tek-seferlik erişim bitişi. Dedup tasarımı ister. |
| C6 | `welcome` + `premium_intro` e-postaları RU-only | Pazarlama kopyası — TR/EN metinleri onayınla yazılır. |
| C7 | Onboarding yarıda kalırsa (kayıt sonrası foto/selfie öncesi çıkış) sonraki açılış feed'e düşüyor | Zorunlu tamamlama akışı mı, mevcut yumuşak kart mı? |
| C8 | Ölü mekanikler: `meeting_reminder`/`feedback_request` bildirim tipleri (üretici yok), `match` push şablonu (çağıran yok), `DecisionScreen`+`'selected'` durumu (product-logic §137: hiç kullanılmıyor) | Temizlik ya da hayata geçirme kararı. Kullanıcı görmüyor; acil değil. |
| C9 | Moderasyon aksiyonları (ilan kapatma, foto silme, uyarı, rapor sonucu) kullanıcıya yansımıyor | Ops paneli olgunlaştıkça bildirim setine bağlanmalı. |

## D. Doğrulanan SAĞLAM alanlar (özet)

Sosyal çekirdek (mesaj/başvuru/seçilme) push+zil çift kanallı ve alıcı dilinde; selfie
karar zinciri sunucu-tetikli çift kanal; keşfet/mesaj listesi/hesap silme ekranları
örnek durum-kapsamalı; arb parite 3 dilde tam (665/665/665); kabul→match→sohbet kuralları
sunucuda zorlanıyor; paywall dönüş-kontrolü çalışıyor.
