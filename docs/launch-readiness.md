# SoulChoice — LAUNCH READINESS TABLOSU

> Tek kaynak. Her düzeltme sonrası güncellenir. Skorlar denetim kanıtına dayanır, pohpohlama yok.
> **Son güncelleme: 13.07.2026 — Büyük Denetim 1. dalga**

## LAUNCH ONAY KURALI
Genel yüzde bilgi amaçlıdır. **Asıl kapı: HER kategori kendi eşiğini geçmeli (AND).**
Bir kategori eşiğin altındaysa — genel yüzde ne olursa olsun — store'a ÇIKILMAZ.
Sebep: güvenlik %89 "neredeyse" değildir; hacker o %11'den girer.

| # | Kategori | Mevcut | Eşik | Durum | Neden bu eşik |
|---|----------|--------|------|-------|---------------|
| 1 | Kod kalitesi | 85% | 85% | ✅ eşikte | Build sağlam; kozmetik borç bloklamaz |
| 2 | **Güvenlik** | 87% | **92%** | 🔴 -5 | Hacker affetmez; kullanıcı+yasal risk |
| 3 | **Para yolu** | 78% | **92%** | 🔴 -14 | Para hatası = itibar + iade felaketi |
| 4 | Ölçeklenme/Altyapı | 55% | 72% | 🔴 -17 | Tek sunucu MVP tamam, ama veri kaybı/kör uçuş olmaz |
| 5 | UX dayanıklılık | 70% | 85% | 🟡 -15 | İlk izlenim; beyaz ekran = silme |
| 6 | **Store hazırlık** | 83% | **90%** | 🟡 -7 | Apple/Google reddi = launch yok |
| 7 | Ürün olgunluk | 72% | 75% | 🟡 -3 | "Yeterince iyi" launch olur; mükemmel şart değil |

**GENEL LAUNCH-READINESS: %77** (ağırlıklı: güvenlik+para+store çift ağırlık)
**LAUNCH-ONAY EŞİĞİ: 7/7 kategori yeşil** → bugün **0/7 hazır değil** (2 kritik + 2 altyapı/ux eşik altında)

---

## AÇIK MADDELER (puanlı — kapatınca kategori % artar)

### 🔴 Güvenlik (87% → hedef 92%, açık -5)
- [x] OTP brute-force → hesap devralma (+8) — **KAPANDI 13.07** (attempt cap, canlı kanıtlı)
- [x] SMS bombing — send-call-otp rate limit (+7) — **KAPANDI 13.07** (60sn cooldown, SMS.ru çağrısından önce, canlı kanıtlı)
- [ ] Edge fn'lerin auth yüzeyi tam denetimi (+3): açık çağrılabilen hassas endpoint kalmadığını doğrula
- [ ] Moderasyon: reports/blocks var ama admin moderasyon paneli yok (+2)

### 🔴 Para yolu (78% → hedef 92%, açık -14)
- [ ] Ödeme çifte-tıklama / ödeme-ortası ağ kopması koruması denetlenmedi (+6)
- [ ] Webhook gecikmesi/tekrar (idempotency) uç durumu (+4)
- [ ] iOS premium ALMA yolu belirsiz (steering yasağı) — kullanıcı özelliği görür, alamaz (+4)

### 🔴 Ölçeklenme/Altyapı (55% → hedef 72%, açık -17)
- [ ] Off-site yedek yok — tüm yedekler tek sunucuda, disk ölürse veri kaybı (+9)
- [ ] İzleme/alarm yok — CPU/disk/DB kritikleşince haber yok (+6)
- [ ] Restore provası yapılmadı — yedek gerçekten dönüyor mu bilinmiyor (+2)

### 🟡 UX dayanıklılık (70% → hedef 85%, açık -15)
- [ ] Kötü koşul (kopuk internet/boş cevap) her ekranda hata/boş/yükleniyor durumu — derin test yapılmadı (+8)
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
- 13.07.2026 — OTP brute-force kapandı → Güvenlik %72→%80, genel %72→%75
- 13.07.2026 — SMS bombing kapandı → Güvenlik %80→%87, genel %75→%77
