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

## C. Karar konuları — 24.07 delegasyonuyla çözüm durumu

Mustafa 24.07: "her biri için kendi önerini uygula; yalnız ürün felsefesi/hukuki risk
değiştirenler tek listeyle sorulur."

| # | Konu | Durum |
|---|------|-------|
| C1 | Ban / no-show askısı bildirimsiz | **MUSTAFA'DA (tek açık karar).** Öneri: askı/ban anında push "Hesabın askıya alındı — detay: support@" (gerekçe metni ve itiraz akışı senin kararın; 152-ФЗ şeffaflık boyutu). Suspended ekranı mevcut, yani kullanıcı app'i açınca öğreniyor; push yalnız öğrenme süresini kısaltır. |
| C2 | ~~Reddedilen başvurana push yok / zil var çelişkisi~~ | **KAPANDI — çelişki yokmuş.** product-logic §9 zaten "Reddedildin: in-app ✅, push ❌ bilinçli" diyor; kod birebir uyumlu. Tarama ajanının yanlış alarmı. |
| C3 | Hesap silme teyidi | **YAPILDI (24.07):** `billing_email` varsa silme sonrası `account_deleted` e-postası (3 dilde, best-effort). |
| C4 | Sosyal push'lar istemci-tetikli | **BACKLOG (post-launch, checklist X):** pg_net trigger'a taşınacak — launch öncesi çekirdek trigger'lara dokunma riski alınmadı. |
| C5 | Tek-seferlik premium bitişi bildirimsiz | **BACKLOG (post-launch, checklist Y):** dedup tasarımı ister; abone grace-sonu 24.07'de kapandı, kalan yüzey küçük. |
| C6 | `welcome`/`premium_intro` RU-only | **YAPILDI (24.07):** TR/EN kopyalar servis tonunda yazıldı (RU orijinaline birebir sadık). |
| C7 | Onboarding yarıda kalma | **KARAR (öneri uygulandı = değişiklik yok):** yumuşak tamamlama kartı kalır; selfie kapısı çekirdek aksiyonları zaten kilitliyor, zorunlu akış drop-off'u artırır. |
| C8 | Ölü mekanikler (meeting_reminder/feedback_request tipleri, match şablonu, DecisionScreen+'selected') | **BACKLOG (post-launch, checklist Z):** kullanıcı görmüyor; store inceleme dönemi kod churn'üne değmez. |
| C9 | Moderasyon aksiyonları bildirimsiz | **BACKLOG (post-launch, checklist Z ile birlikte; C1 kararına bağlı).** |

## D. Doğrulanan SAĞLAM alanlar (özet)

Sosyal çekirdek (mesaj/başvuru/seçilme) push+zil çift kanallı ve alıcı dilinde; selfie
karar zinciri sunucu-tetikli çift kanal; keşfet/mesaj listesi/hesap silme ekranları
örnek durum-kapsamalı; arb parite 3 dilde tam (665/665/665); kabul→match→sohbet kuralları
sunucuda zorlanıyor; paywall dönüş-kontrolü çalışıyor.
