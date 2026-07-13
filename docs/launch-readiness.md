# SoulChoice — LAUNCH READINESS TABLOSU

> Tek kaynak. Her düzeltme sonrası güncellenir. Skorlar denetim kanıtına dayanır, pohpohlama yok.
> **Son güncelleme: 13.07.2026 — Büyük Denetim 1. dalga**

## LAUNCH ONAY KURALI
Genel yüzde bilgi amaçlıdır. **Asıl kapı: HER kategori kendi eşiğini geçmeli (AND).**
Bir kategori eşiğin altındaysa — genel yüzde ne olursa olsun — store'a ÇIKILMAZ.
Sebep: güvenlik %89 "neredeyse" değildir; hacker o %11'den girer.

| # | Kategori | Mevcut | Eşik | Durum | Neden bu eşik |
|---|----------|--------|------|-------|---------------|
| 1 | Kod kalitesi | 86% | 85% | ✅ | Build sağlam; paywall leak kapandı |
| 2 | **Güvenlik** | 90% | **92%** | 🟡 -2 | Hacker affetmez; kullanıcı+yasal risk |
| 3 | **Para yolu** | 88% | **92%** | 🟡 -4 | Para hatası = itibar + iade felaketi |
| 4 | Ölçeklenme/Altyapı | 55% | 72% | 🔴 -17 | Tek sunucu MVP tamam, ama veri kaybı/kör uçuş olmaz |
| 5 | UX dayanıklılık | 76% | 85% | 🟡 -9 | İlk izlenim; beyaz ekran = silme |
| 6 | **Store hazırlık** | 83% | **90%** | 🟡 -7 | Apple/Google reddi = launch yok |
| 7 | Ürün olgunluk | 72% | 75% | 🟡 -3 | "Yeterince iyi" launch olur; mükemmel şart değil |

**GENEL LAUNCH-READINESS: %83** (ağırlıklı: güvenlik+para+store çift ağırlık)
**LAUNCH-ONAY EŞİĞİ: 7/7 kategori yeşil** → bugün **1/7 hazır** (Kod). Kalan: Güvenlik -5, Para -4, Altyapı -17, UX -15, Store -7, Ürün -3

---

## AÇIK MADDELER (puanlı — kapatınca kategori % artar)

### 🟡 Güvenlik (90% → hedef 92%, açık -2)
- [x] OTP brute-force → hesap devralma (+8) — **KAPANDI 13.07** (attempt cap, canlı kanıtlı)
- [x] SMS bombing — send-call-otp rate limit (+7) — **KAPANDI 13.07** (60sn cooldown, SMS.ru çağrısından önce, canlı kanıtlı)
- [x] Edge fn auth yüzeyi (+3) — **DENETLENDİ TEMİZ 13.07** (delete-account getUser-JWT; diğerleri user-token forward+RLS; IDOR yok)
- [ ] Moderasyon paneli (+2) — reports/blocks çalışıyor, manuel SQL yönetilebilir; launch-blocker DEĞİL ama launch günü manuel moderasyon prosedürü hazır olmalı (KARAR: eşik %90 kabul mü, panel şart mı?)

### 🟡 Para yolu (88% → hedef 92%, açık -4)
- [x] Ödeme çifte-tıklama / ağ kopması (+6) — **DENETLENDİ SAĞLAM 13.07** (_isLoading+sheetBusy guard; webhook Точка'dan bağımsız)
- [x] Webhook idempotency (+4) — **DENETLENDİ SAĞLAM 13.07** (on conflict do nothing + zaten-işlenmiş guard)
- [ ] iOS premium ALMA yolu (+4) — **ÜRÜN KARARI (Mustafa)**, teknik borç değil: iOS'ta web'e yönlendirme UX'i netleşmeli; Android+web ödeme launch-hazır

### 🔴 Ölçeklenme/Altyapı (55% → hedef 72%, açık -17)
- [ ] Off-site yedek yok — tüm yedekler tek sunucuda, disk ölürse veri kaybı (+9)
- [ ] İzleme/alarm yok — CPU/disk/DB kritikleşince haber yok (+6)
- [ ] Restore provası yapılmadı — yedek gerçekten dönüyor mu bilinmiyor (+2)

### 🟡 UX dayanıklılık (76% → hedef 85%, açık -9)
- [x] Offline soğuk açılış — splash sonsuz takılıyordu (+6) — **KAPANDI 13.07** (timeout+fallback, offline'da feed'e geçiyor, online regresyon temiz)
- [ ] Yavaş-ağ her ekran + boş cevap durumu — derin test sürüyor (+2)
- [ ] Uç durumlar (silinmiş kullanıcının eski mesajı, premium bitmiş, dolmuş davet) — derin test (+5)
- [ ] Geri-dönüşsüz anlar (silme/iptal/engelleme) onay yeterliliği (+2)

### 🟡 Store hazırlık (83% → hedef 90%, açık -7)
- [ ] Android WRITE_EXTERNAL_STORAGE gereksiz izin (+2)
- [ ] Store ekran görüntüleri (C) — cihazda çekilecek (+3)
- [ ] Store metinleri (D) onayı (+2)

### 🟡 Ürün olgunluk (72% → hedef 75%, açık -3)
- [ ] Onboarding fark-anlatımı + ilk davet sonrası yönlendirme (+2)
- [ ] Retention nudge (ilk 48s başvuru gelmezse) (+1)

---

## KAPANIŞ GÜNLÜĞÜ
- 13.07.2026 — paywall controller leak kapandı → Kod %85→%86
- 13.07.2026 — Offline splash takılması kapandı → UX %70→%76, genel %81→%83
- 13.07.2026 — Edge auth denetlendi temiz (IDOR yok) → Güvenlik %87→%90, genel %80→%81
- 13.07.2026 — OTP brute-force kapandı → Güvenlik %72→%80, genel %72→%75
- 13.07.2026 — SMS bombing kapandı → Güvenlik %80→%87, genel %75→%77
- 13.07.2026 — Para yolu denetlendi (çifte-tıklama+idempotency sağlam) → Para %78→%88, genel %77→%80
