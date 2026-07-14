# SoulChoice — LAUNCH READINESS TABLOSU

> Tek kaynak. Her düzeltme sonrası güncellenir. Skorlar denetim kanıtına dayanır, pohpohlama yok.
> **Son güncelleme: 14.07.2026 — Para yolu eşiği GEÇİLDİ (iOS consumption-only kararı + retry kapısı)**

## LAUNCH ONAY KURALI
Genel yüzde bilgi amaçlıdır. **Asıl kapı: HER kategori kendi eşiğini geçmeli (AND).**
Bir kategori eşiğin altındaysa — genel yüzde ne olursa olsun — store'a ÇIKILMAZ.
Sebep: güvenlik %89 "neredeyse" değildir; hacker o %11'den girer.

| # | Kategori | Mevcut | Eşik | Durum | Neden bu eşik |
|---|----------|--------|------|-------|---------------|
| 1 | Kod kalitesi | 86% | 85% | ✅ | Build sağlam; paywall leak kapandı |
| 2 | **Güvenlik** | 90% | **92%** | 🟡 -2 | Hacker affetmez; kullanıcı+yasal risk |
| 3 | **Para yolu** | 92% | **92%** | ✅ | Para hatası = itibar + iade felaketi |
| 4 | Ölçeklenme/Altyapı | 61% | 72% | 🔴 -11 | Tek sunucu MVP tamam, ama veri kaybı/kör uçuş olmaz |
| 5 | UX dayanıklılık | 76% | 85% | 🟡 -9 | İlk izlenim; beyaz ekran = silme |
| 6 | **Store hazırlık** | 85% | **90%** | 🟡 -5 | Apple/Google reddi = launch yok |
| 7 | Ürün olgunluk | 72% | 75% | 🟡 -3 | "Yeterince iyi" launch olur; mükemmel şart değil |

**GENEL LAUNCH-READINESS: %86** (ağırlıklı: güvenlik+para+store çift ağırlık)
**LAUNCH-ONAY EŞİĞİ: 7/7 kategori yeşil** → bugün **2/7 hazır** (Kod, Para). Kalan: Güvenlik -2, Altyapı -11, UX -9, Store -5, Ürün -3

---

## AÇIK MADDELER (puanlı — kapatınca kategori % artar)

### 🟡 Güvenlik (90% → hedef 92%, açık -2)
- [x] OTP brute-force → hesap devralma (+8) — **KAPANDI 13.07** (attempt cap, canlı kanıtlı)
- [x] SMS bombing — send-call-otp rate limit (+7) — **KAPANDI 13.07** (60sn cooldown, SMS.ru çağrısından önce, canlı kanıtlı)
- [x] Edge fn auth yüzeyi (+3) — **DENETLENDİ TEMİZ 13.07** (delete-account getUser-JWT; diğerleri user-token forward+RLS; IDOR yok)
- [ ] Moderasyon paneli (+2) — reports/blocks çalışıyor, manuel SQL yönetilebilir; launch-blocker DEĞİL ama launch günü manuel moderasyon prosedürü hazır olmalı (KARAR: eşik %90 kabul mü, panel şart mı?)

### ✅ Para yolu (92% → hedef 92% — EŞİK GEÇİLDİ 14.07)
- [x] Ödeme çifte-tıklama / ağ kopması (+6) — **DENETLENDİ SAĞLAM 13.07** (_isLoading+sheetBusy guard; webhook Точка'dan bağımsız)
- [x] Webhook idempotency (+4) — **DENETLENDİ SAĞLAM 13.07** (on conflict do nothing + zaten-işlenmiş guard)
- [x] iOS premium ALMA yolu (+4) — **KAPANDI 14.07 (KARAR Mustafa: consumption-only, ödeme SADECE web portalı).** Kod denetimi: paywall Seçenek B zaten canlıydı (36fe92b1e — iOS'ta fiyat/CTA/web-linki yok, 3.1.1-uyumlu); tek kalıntı `past_due` retry butonuydu → `_mode=='link'` kapısına alındı (bu commit). Dart kodunda web ödeme URL'i sızıntısı yok (tarandı). Dış yönlendirme kanalı (F2 e-posta digest) canlı. İptal butonu iOS'ta görünür kalır (F2-2 uyumlu).

### 🔴 Ölçeklenme/Altyapı (61% → hedef 72%, açık -11)
- [ ] Off-site yedek yok — tüm yedekler tek sunucuda, disk ölürse veri kaybı (+9) — **KARAR 14.07: Yandex Object Storage**; ИП hesap aktivasyonu bekleniyor (ЕГРИП resmi verifikasyon formundan gönderildi 14.07, ≤3 iş günü)
- [x] İzleme/alarm (+6) — **KAPANDI 14.07** (Telegram bot `soulchoice_alerts_bot`: sunucu-içi 15dk disk/yedek/web/functions/container + 08:05 UTC billing denetimi, `/root/monitoring/`; dış-uptime GitHub Actions 10dk `soulchoice-ops/uptime.yml`; token GPG'li `soulchoice-secrets` + GHA secrets, git'te düz metin yok; test alarmı cihazda kanıtlı)
- [ ] Restore provası yapılmadı — yedek gerçekten dönüyor mu bilinmiyor (+2)

### 🟡 UX dayanıklılık (76% → hedef 85%, açık -9)
- [x] Offline soğuk açılış — splash sonsuz takılıyordu (+6) — **KAPANDI 13.07** (timeout+fallback, offline'da feed'e geçiyor, online regresyon temiz)
- [ ] Yavaş-ağ her ekran + boş cevap durumu — derin test sürüyor (+2)
- [ ] Uç durumlar (silinmiş kullanıcının eski mesajı, premium bitmiş, dolmuş davet) — derin test (+5)
- [ ] Geri-dönüşsüz anlar (silme/iptal/engelleme) onay yeterliliği (+2)

### 🟡 Store hazırlık (85% → hedef 90%, açık -5)
- [x] Android WRITE_EXTERNAL_STORAGE gereksiz izin (+2) — **KAPANDI 14.07** (manifest'ten kaldırıldı, commit b1fc88188, iki CI yeşil; hiçbir paket kullanmıyordu)
- [ ] Store ekran görüntüleri (C) — cihazda çekilecek (+3)
- [ ] Store metinleri (D) onayı (+2)

### 🟡 Ürün olgunluk (72% → hedef 75%, açık -3)
- [ ] Onboarding fark-anlatımı + ilk davet sonrası yönlendirme (+2)
- [ ] Retention nudge (ilk 48s başvuru gelmezse) (+1)

---

## KAPANIŞ GÜNLÜĞÜ
- 14.07.2026 — iOS premium yolu kapandı (KARAR: consumption-only + web-only ödeme; retry kapısı) → Para %88→%92 ✅ EŞİK, genel %85→%86
- 14.07.2026 — İzleme/alarm kapandı (Telegram bot + GHA dış-uptime, test alarmı cihazda) → Altyapı %55→%61, genel %84→%85
- 14.07.2026 — WRITE_EXTERNAL_STORAGE izni kaldırıldı → Store %83→%85, genel %83→%84
- 13.07.2026 — paywall controller leak kapandı → Kod %85→%86
- 13.07.2026 — Offline splash takılması kapandı → UX %70→%76, genel %81→%83
- 13.07.2026 — Edge auth denetlendi temiz (IDOR yok) → Güvenlik %87→%90, genel %80→%81
- 13.07.2026 — OTP brute-force kapandı → Güvenlik %72→%80, genel %72→%75
- 13.07.2026 — SMS bombing kapandı → Güvenlik %80→%87, genel %75→%77
- 13.07.2026 — Para yolu denetlendi (çifte-tıklama+idempotency sağlam) → Para %78→%88, genel %77→%80

---

## ⏸️ GECE DURDU (13.07.2026 ~03:30) — YARIN SIFIR BAĞLAMLA DEVAM

**Genel: %83.** Kapananlar (hepsi canlı+kanıtlı, main'de): OTP brute-force, SMS bombing, edge-auth denetimi, para-yolu denetimi, offline-splash takılması, paywall leak.

**Kategori durumu:** Kod %86✅ · Güvenlik %90 (-2 moderasyon) · Para %88 (-4 iOS premium) · Altyapı %55 (-17) · UX %76 (-9) · Store %83 (-7) · Ürün %72 (-3). Launch kapısı: 1/7 eşikte (Kod). Altyapı en büyük açık.

**Benim tek başıma ilerletebileceklerim (kaynak gerektirmez, yarın devam):**
- UX: yavaş-ağ her ekran testi + uç durumlar (silinmiş kullanıcı eski mesajı, premium bitmiş, dolmuş davet) → +9
- Store: iOS/Android son kontrol, C(screenshot cihazda), D(metin onayı)
- Ürün: onboarding fark-anlatımı + retention nudge kod işi
- Altyapı: off-site yükleme + alarm SCRIPT'lerini kredensiyelsiz yazıp hazır bırak (aktivasyon kredensiyelle)

## ⚖️ BEKLEYEN KARARLAR (Mustafa) — bunlar gelmeden ilgili kategoriler tavana ulaşamaz
1. **Off-site yedek hedefi** (Altyapı +9): ~~Backblaze~~ **KARAR 14.07: Yandex Object Storage** (152-ФЗ + yaptırım riski + Object Lock gerekçesiyle; Backblaze ABD riski nedeniyle elendi). Hesap aktivasyonu bekleniyor (ЕГРИП formdan gönderildi); anahtar+bucket gelince script'ler hazır.
2. ~~**Alarm kanalı** (Altyapı +6)~~ — **KARAR VERİLDİ + KURULDU 14.07** (Telegram bot canlı, bkz. Altyapı maddesi).
3. **Moderasyon eşiği** (Güvenlik +2): panel launch-blocker mı, yoksa launch günü manuel SQL+engelleme/rapor yeterli mi (önerim: manuel yeterli, panel ilk 2 hafta).
4. ~~**iOS premium alma yolu** (Para +4)~~ — **KARAR VERİLDİ + UYGULANDI 14.07** (consumption-only, ödeme sadece web; bkz. Para maddesi).
