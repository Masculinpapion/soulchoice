# SoulChoice — Claude Code Talimatları

[Güvenlik: Bu bilgiler güvenli kanalda saklanmaktadır]

## CONTAINER ADLARI

- supabase-db (Postgres)
- supabase-auth (GoTrue)
- supabase-rest (PostgREST)
- supabase-realtime
- supabase-storage
- supabase-kong (API gateway)

## PROJE BİLGİLERİ

- Flutter 3.41.7, Dart 3.11.5
- App ID: com.soulchoice.soulchoice
- GitHub: github.com/Masculinpapion/soulchoice
- Test user: [Güvenlik: Bu bilgiler güvenli kanalda saklanmaktadır]

## SUPABASE ENDPOINTS

- API: https://soulchoice.app/rest/v1/
- Storage: https://soulchoice.app/storage/v1/
- Auth: https://soulchoice.app/auth/v1/
- Backend sunucu: Timeweb 89.169.1.127 (Hetzner terkedildi)

API keys: lib/core/constants/supabase_constants.dart

## ADB TELEFON KOMUTLARI

```
adb devices
adb shell input tap X Y
adb shell input swipe X1 Y1 X2 Y2 500
adb shell input text "metin"
adb exec-out screencap -p > /tmp/screen.png
adb shell am force-stop com.soulchoice.soulchoice
adb shell monkey -p com.soulchoice.soulchoice -c android.intent.category.LAUNCHER 1
kill -SIGUSR2 $(cat /tmp/flutter.pid)  # hot restart
```

## DEVELOPMENT

- APK build: /tmp/sc-build/ klasörü, yoksa git clone
- Disk dolarsa: sudo rm -rf /private/tmp/claude-501
- Marka: SoulChoice, "Choose Your Night"
- 4 dil: TR/RU/EN/DE
- Renk: kırmızı+mavi hap, glassmorphism

[Güvenlik: Bu bilgiler güvenli kanalda saklanmaktadır]

## KURAL

Her bug fix öncesi:
1. View ile dosyayı oku
2. Grep ile satırı bul
3. str_replace ile düzelt
4. kill -SIGUSR2 ile hot restart
5. adb ile test et

## EKRAN GÖRÜNTÜSÜ KURALI

ASLA kullanıcı istemeden screenshot ALMA.
Kullanıcı telefonu canlı görüyor, screenshot
gereksiz kredi yakar. Sadece kullanıcı
'screenshot al' derse al.

## ASİL VERSİYON — carousel-v1

Bu proje HER ZAMAN bu commit üzerinden gelişir:
- **Tag:** `carousel-v1`
- **Commit:** `707ae11` (707ae1123f4964a384f7e05f7e352237e0b936b2)
- **Mesaj:** Feed: sonsuz halka carousel — ilk kartta solda da gölge görünür
- **GitHub main:** bu commit'e force-push edildi (2026-04-29)

Kurtarma (main kaybolursa):
```
git fetch origin carousel-v1
git reset --hard carousel-v1
git push origin main --force
```

Feed tasarımı:
- viewportFraction: 0.72, padEnds: true
- _initRing ile sonsuz halka (itemCount × 1000)
- "GÜNÜN DAVETLERİ · KAYDIR →" başlığı
- Story avatarlar gradient halka
- Davetler / İstekler pill sekmeler

[Güvenlik: Bu bilgiler güvenli kanalda saklanmaktadır]

---

# PRODUCTION READINESS — YAPILACAKLAR LİSTESİ (2026-06-19)

## Teknik / Yazılım
- [x] **KRİTİK:** Admin route guard — zaten mevcuttu (router.dart:77-86, is_admin kontrol + redirect → /feed)
- [x] **KRİTİK:** iOS Info.plist UsageDescription metinleri düzeltildi (commit b27d125, 6 izin temiz İngilizce)
- [ ] 218 bang assertion (!.) audit — en sık crash olan yolları null-safe yap
- [ ] 53 controller dispose audit (TextEditingController, PageController, AnimationController, TabController)
- [ ] 356 deprecated_member_use (withOpacity → withValues) Material 3 geçişi
- [ ] App icon assets küçült (1.3MB × 2 → 400KB altı)
- [ ] iOS gerçek cihazda FCM token kaydet — Build 3'te test (GoogleService-Info.plist var, kod tarafı kontrol)

## Store Hazırlık
- [ ] Google Play Console — uygulama sayfası oluştur (kimlik onayı zaten ✅)
- [ ] Apple App Store Connect — uygulama oluştur (Apple Developer aktif ✅, TestFlight Build 2 "Waiting for Review")
- [ ] Store açıklamaları (TR/RU/EN) yaz — kısa + uzun + keywords
- [ ] Store screenshot'ları hazırla (Play min 2, App Store min 3, TR+RU)
- [ ] App Store içerik derecelendirmesi anketi (yaş sınırı)
- [ ] Google Play İçerik Derecelendirmesi anketi
- [ ] Veri güvenliği formu (Google Play "Data safety")
- [ ] App Privacy form (App Store)
- [ ] RuStore hesabı aç + uygulama yükle (ИП sonrası)

## Web Sitesi
- [ ] **KRİTİK:** soulchoice.app ana sayfa içeriği (şu an 401 — Apple/Google reddeder)
- [x] Privacy Policy — soulchoice.app/privacy (RU, dolu ✅)
- [x] Terms of Service — soulchoice.app/terms (✅)
- [ ] Privacy Policy TR + EN versiyonları (şu an sadece RU)
- [ ] Terms TR + EN versiyonları
- [ ] Destek e-postası (support@soulchoice.app) DNS + IMAP/SMTP
- [ ] App Store "Marketing URL" ve "Support URL" için public sayfalar

## Kontrol Paneli (Admin)
- [x] Selfie onay/red sistemi (`_PendingSelfiestTab` ✅)
- [x] Rapor yönetimi (`_ReportsTab` ✅)
- [x] Kullanıcı banlama (`_banUser` ✅)
- [ ] **KRİTİK:** Admin paneline `is_admin` flag tabanlı route guard
- [ ] Tüm kullanıcı listesi + arama + filtreleme (şu an YOK)
- [ ] Manuel ödeme/abonelik takibi (premium kullanıcı listesi, expires_at)
- [ ] Server durumu monitörü (uptime/CPU/RAM/disk)
- [ ] Push bildirim toplu gönderme paneli (broadcast announcement)
- [ ] Davet moderasyonu (uygunsuz davetiyeleri kaldır)
- [ ] Analitik dashboard (DAU/MAU/conversion)

## Ödeme Sistemi
- [x] Paywall ekranı UI (TR/RU/EN ✅, commit 4c55f42)
- [x] DB altyapı: `free_application_used` + `can_user_apply` RPC + trigger (commit 359442c)
- [ ] YooKassa hesabı aç (ИП kuruluşu sonrası)
- [ ] YooKassa Flutter entegrasyonu (in-app webview checkout)
- [ ] Edge function: `start-subscription` (YooKassa checkout URL döner)
- [ ] Edge function: `yookassa-webhook` (ödeme onay/red işleme, subscription_status update)
- [ ] Edge function: `cancel-subscription` (kullanıcı iptal)
- [ ] Kayıtlı kart ile otomatik aylık yenileme cron
- [ ] Başarısız ödeme bildirimi + 3 gün grace period
- [ ] Abonelik durumu Settings ekranında göster (aktif, sonraki ödeme tarihi, iptal)

## Yasal / İdari
- [ ] **BLOKLAYICI:** Rusya ИП/ООО açılışı (RuStore + YooKassa için ön koşul)
- [ ] Marka tescili Rusya (Роспатент — new.fips.ru)
- [ ] Marka tescili Global (WIPO — madrid.wipo.int)
- [ ] SMS.ru sender adı onayı (commercial sender)
- [x] Apple Developer Program ✅
- [ ] Apple Developer kullanım sözleşmeleri imzalı mı kontrol
- [ ] KVKK (TR) / GDPR (EU) / 152-ФЗ (RU) uyumluluk gözden geçirme
- [ ] Rusya'da veri saklama yasası (152-ФЗ) — DB Moskova'da ✅

## Güvenlik
- [x] **KRİTİK:** subscriptions tablosuna RLS eklendi (commit 03b3496, owner-only SELECT + service_role manage)
- [x] **KRİTİK:** user_devices tablosuna RLS eklendi (owner-only ALL)
- [x] **KRİTİK:** notification_preferences RLS eklendi (owner-only ALL)
- [x] call_otps RLS eklendi (service_role only)
- [x] user_stats RLS eklendi (owner SELECT + service_role manage)
- [ ] cities/feature_flags RLS public okuma olarak bırak (doğru)
- [x] **KRİTİK:** DB otomatik yedekleme kuruldu (commit 73cd959, cron 03:00 docker exec pg_dump + 7 gün retention, /root/backups/)
- [ ] Yedek **off-site** kopyalama (Timeweb panel snapshot teyit edilecek; gerekirse Hetzner Storage Box veya GitHub Releases)
- [ ] Yedek restore prosedürü dokümantasyonu + test
- [ ] Storage bucket policy review (profile-photos public mi? selfies private olmalı)
- [ ] Rate limiting edge function'larda (OTP brute force, paywall abuse)
- [ ] Sentry/log aggregation (Crashlytics zaten var ama backend log yok)

## CI/CD
- [x] Debug APK build CI ✅
- [x] Release AAB build CI ✅
- [ ] Edge Function deploy CI'a entegre (şu an manuel SSH ile uygulanıyor)
- [ ] DB migration CI auto-apply (şu an manuel `psql < migration.sql`)
- [ ] iOS TestFlight build CI (şu an manuel xcodebuild)
- [ ] Pre-commit hook: dart analyze + format
- [ ] Branch koruması: main'e direct push yasak, PR zorunlu (şu an direct push yapılıyor)

## Lokalizasyon
- [x] TR/RU/EN .arb dosyaları senkron (her biri 776 satır ✅)
- [x] Hardcoded TR string YOK ✅
- [ ] iOS Info.plist UsageDescription — her dil için `.lproj/InfoPlist.strings`
- [ ] App Store Connect lokalize metadata (TR + RU + EN)

## Özet (öncelik sırası)
1. ИП kuruluşu → YooKassa entegrasyonu (en uzun süren)
2. Admin route guard + RLS düzeltmeleri (1 oturum)
3. iOS Info.plist + soulchoice.app ana sayfa (1 oturum)
4. DB backup cron (30 dk)
5. Store screenshot + açıklama (1 oturum)
6. Google Play Internal Testing → Production review

## HUKUKİ

- Detaylı kayıt/checklist: docs/legal-todos.md
- Roskomnadzor kişisel veri operatörü bildirimi: TAMAMLANDI (07.07.2026)
