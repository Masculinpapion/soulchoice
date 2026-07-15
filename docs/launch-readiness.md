# SoulChoice — LAUNCH READINESS TABLOSU

> Tek kaynak. Her düzeltme sonrası güncellenir. Skorlar denetim kanıtına dayanır, pohpohlama yok.
> **Son güncelleme: 15.07.2026 — Altyapı eşiği de GEÇİLDİ (off-site immutable + restore provası); 5/7 eşikte, genel %92**

## LAUNCH ONAY KURALI
Genel yüzde bilgi amaçlıdır. **Asıl kapı: HER kategori kendi eşiğini geçmeli (AND).**
Bir kategori eşiğin altındaysa — genel yüzde ne olursa olsun — store'a ÇIKILMAZ.
Sebep: güvenlik %89 "neredeyse" değildir; hacker o %11'den girer.

| # | Kategori | Mevcut | Eşik | Durum | Neden bu eşik |
|---|----------|--------|------|-------|---------------|
| 1 | Kod kalitesi | 86% | 85% | ✅ | Build sağlam; paywall leak kapandı |
| 2 | **Güvenlik** | 92% | **92%** | ✅ | Hacker affetmez; kullanıcı+yasal risk |
| 3 | **Para yolu** | 93% | **92%** | ✅ | Para hatası = itibar + iade felaketi |
| 4 | Ölçeklenme/Altyapı | 72% | 72% | ✅ | Tek sunucu MVP tamam, ama veri kaybı/kör uçuş olmaz |
| 5 | UX dayanıklılık | 83% | 85% | 🟡 -2 | İlk izlenim; beyaz ekran = silme |
| 6 | **Store hazırlık** | 86% | **90%** | 🟡 -4 | Apple/Google reddi = launch yok |
| 7 | Ürün olgunluk | 75% | 75% | ✅ | "Yeterince iyi" launch olur; mükemmel şart değil |

**GENEL LAUNCH-READINESS: %92** (ağırlıklı: güvenlik+para+store çift ağırlık)
**LAUNCH-ONAY EŞİĞİ: 7/7 kategori yeşil** → bugün **5/7 hazır** (Kod, Para, Güvenlik, Ürün, Altyapı). Kalan: UX -2, Store -4

---

## AÇIK MADDELER (puanlı — kapatınca kategori % artar)

### ✅ Güvenlik (92% → hedef 92% — EŞİK GEÇİLDİ 14.07)
- [x] OTP brute-force → hesap devralma (+8) — **KAPANDI 13.07** (attempt cap, canlı kanıtlı)
- [x] SMS bombing — send-call-otp rate limit (+7) — **KAPANDI 13.07** (60sn cooldown, SMS.ru çağrısından önce, canlı kanıtlı)
- [x] Edge fn auth yüzeyi (+3) — **DENETLENDİ TEMİZ 13.07** (delete-account getUser-JWT; diğerleri user-token forward+RLS; IDOR yok)
- [x] Moderasyon paneli (+2) — **KAPANDI 14.07 (Mustafa kararı: manuel değil, panel).** Ops panelde Moderasyon sekmesi CANLI: selfie kuyruğu (foto disk-proxy) + şikayet kuyruğu (5 aksiyon) + ConfirmDialog + audit_log; kısıtlı `ops_moderator` rolü (izolasyon 6 testle kanıtlı, service_role yok). E2E kanıtlı: 5 RPC gerçek akışla (approve/reject/warn/ban/resolve — audit dökümüyle), 2 RPC not-found yoluyla; test verisi psql kanıtıyla birebir geri alındı (verified_at dahil). Ekstra: ufw + DOCKER-USER (5432/6543/8000/8443 dışa kapandı, 14.07).

### ✅ Para yolu (92% → hedef 92% — EŞİK GEÇİLDİ 14.07)
- [x] Ödeme çifte-tıklama / ağ kopması (+6) — **DENETLENDİ SAĞLAM 13.07** (_isLoading+sheetBusy guard; webhook Точка'dan bağımsız)
- [x] Webhook idempotency (+4) — **DENETLENDİ SAĞLAM 13.07** (on conflict do nothing + zaten-işlenmiş guard)
- [x] iOS premium ALMA yolu (+4) — **KAPANDI 14.07 (KARAR Mustafa: consumption-only, ödeme SADECE web portalı).** Kod denetimi: paywall Seçenek B zaten canlıydı (36fe92b1e — iOS'ta fiyat/CTA/web-linki yok, 3.1.1-uyumlu); tek kalıntı `past_due` retry butonuydu → `_mode=='link'` kapısına alındı (bu commit). Dart kodunda web ödeme URL'i sızıntısı yok (tarandı). Dış yönlendirme kanalı (F2 e-posta digest) canlı. İptal butonu iOS'ta görünür kalır (F2-2 uyumlu).

### ✅ Ölçeklenme/Altyapı (72% → hedef 72% — EŞİK GEÇİLDİ 15.07)
- [x] Off-site yedek (+9) — **KAPANDI 15.07**: Yandex Object Storage (soulchoice-backups, Standard sınıf, **Object Lock COMPLIANCE 14 gün immutable**, versioning). Gece 04:00 cron: pg_dump + storage(xattr korumalı tar) → GPG AES256 şifreli → rclone Standard yükleme. İlk yükleme kanıtlı (2 obje 56MB, retention 2026-07-29). Servis hesabı geçici admin ile kuruldu → uploader'a düşürüldü.
- [x] İzleme/alarm (+6) — **KAPANDI 14.07** (Telegram bot `soulchoice_alerts_bot`: sunucu-içi 15dk disk/yedek/web/functions/container + 08:05 UTC billing denetimi, `/root/monitoring/`; dış-uptime GitHub Actions 10dk `soulchoice-ops/uptime.yml`; token GPG'li `soulchoice-secrets` + GHA secrets, git'te düz metin yok; test alarmı cihazda kanıtlı)
- [x] Restore provası (+2) — **KAPANDI 15.07**: ayrı test container'da bucket'tan indir→GPG çöz→doğrula. DB dump canlıyla BİREBİR eşleşti (users99/inv65/matches3), storage tar xattr (content-type/cache-control) korundu. Ops panel Veri & Yedek sekmesi gerçek veriyle (agent /api/backup/stats + last-restore-drill damgası) — off-site AKTİF + restore yeşil. Alarm off-site yükleme başarısızlığını kapsıyor (checks.sh offsite kontrolü).

### 🟡 UX dayanıklılık (83% → hedef 85%, açık -2)
- [x] Offline soğuk açılış — splash sonsuz takılıyordu (+6) — **KAPANDI 13.07** (timeout+fallback, offline'da feed'e geçiyor, online regresyon temiz)
- [ ] Yavaş-ağ her ekran + boş cevap durumu — derin test sürüyor (+2)
- [x] Uç durumlar (+5) — **KAPANDI 15.07**: 'Silinen kullanıcı' modeli (karşı taraf sohbeti korur, S24 cihaz kanıtlı) + dolmuş davette pending→expired + 'seçim yapılmadı' gösterimi + premium grace-period zaten sağlamdı
- [x] Geri-dönüşsüz anlar (+2) — **KAPANDI 15.07**: hesap silme (onaylı ekran + artık gerçekten çalışıyor), engelleme (onay dialoglu), sohbet 'sil'→tek-taraflı 'gizle' (WhatsApp standardı, net onay metni, geri-dönüşü var)

### 🟡 Store hazırlık (86% → hedef 90%, açık -4)
- [x] Store incelemeci demo girişi (+1) — **KAPANDI 15.07** (+7 000 000-00-01/1234, tahsis-edilemez blok, ALLOW_TEST_OTP kapılı, docs/store-review-demo.md; içinde örnek sohbet fikstürü)
- [x] Android WRITE_EXTERNAL_STORAGE gereksiz izin (+2) — **KAPANDI 14.07** (manifest'ten kaldırıldı, commit b1fc88188, iki CI yeşil; hiçbir paket kullanmıyordu)
- [ ] Store ekran görüntüleri (C) — cihazda çekilecek (+3)
- [ ] Store metinleri (D) onayı (+2)

### ✅ Ürün olgunluk (75% → hedef 75% — EŞİK GEÇİLDİ 15.07)
- [x] Ürün-mantığı denetimi (+3) — **15.07**: docs/product-logic.md TEK KAYNAK (v1.4); kabul akışı kırığı (RLS sessiz yutma — başvuran seçildiğini HİÇ öğrenemiyordu) + kabul bildirimi + başvuru kurallarının sunucuda zorlanması (premium bypass kapandı) + yaş filtresi bağlandı + çift yönlü engelleme + buluşma anketi/arşiv canlandı + mark-read düzeldi
- [ ] Onboarding fark-anlatımı + ilk davet sonrası yönlendirme (+2)
- [ ] Retention nudge (ilk 48s başvuru gelmezse) (+1)

---

## KAPANIŞ GÜNLÜĞÜ
- 15.07.2026 — Off-site immutable yedek (Yandex Object Lock 14g) + restore provası (DB canlıyla eşleşti + xattr korundu) + ops panel Veri&Yedek gerçek veri + alarm off-site kapsama → Altyapı %61→%72 ✅ EŞİK, genel %89→%92
- 15.07.2026 — Ürün-mantığı denetimi: kabul akışı kırığı + kabul bildirimi + sunucu-taraflı başvuru kuralları + yaş filtresi + çift yönlü engelleme + hide-chat + buluşma mekaniği + silinen-kullanıcı modeli (GDPR) + mark-read → Ürün %72→%75 ✅ EŞİK, UX %76→%83, Para %92→%93, Store %85→%86, genel %87→%89
- 14.07.2026 — Moderasyon paneli kapandı (E2E kanıtlı) → Güvenlik %90→%92 ✅ EŞİK, genel %86→%87
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
1. **Off-site yedek hedefi** (Altyapı +9): ~~Backblaze~~ **KARAR 14.07: Yandex Object Storage** (152-ФЗ + yaptırım riski + Object Lock gerekçesiyle; Backblaze ABD riski nedeniyle elendi). Hesap aktivasyonu bekleniyor (ЕГРИП formdan gönderildi); anahtar+bucket gelince script'ler hazır. **15.07: hesap AKTİF (ödemeli + 10.000₽ grant) — plan sunuldu, Mustafa'nın Yandex yetkilendirmesi bekleniyor (bkz. oturum planı).**
2. ~~**Alarm kanalı** (Altyapı +6)~~ — **KARAR VERİLDİ + KURULDU 14.07** (Telegram bot canlı, bkz. Altyapı maddesi).
3. ~~**Moderasyon eşiği** (Güvenlik +2)~~ — **KARAR VERİLDİ + PANEL KURULDU 14.07** (bkz. Güvenlik maddesi).
4. ~~**iOS premium alma yolu** (Para +4)~~ — **KARAR VERİLDİ + UYGULANDI 14.07** (consumption-only, ödeme sadece web; bkz. Para maddesi).
