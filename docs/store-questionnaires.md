# Mağaza Anketleri Cevap Kağıdı (E maddesi) — 16.07.2026

Mustafa'nın konsollarda dolduracağı formların hazır cevapları. Kaynak: gerçek uygulama davranışı (kod + docs/product-logic.md). Tereddütte kalınan soruda BURAYA değil koda bakılır.

## 1) Google Play — İçerik Derecelendirmesi (IARC anketi)
- Kategori: **Flört (Dating)** uygulaması
- Şiddet / korku: YOK · Cinsel içerik: uygulama içeriğinde YOK (kullanıcı içeriği ayrı soru) · Küfür: YOK · Kontrollü madde: YOK · Kumar: YOK
- **Kullanıcı etkileşimi: VAR** — kullanıcılar mesajlaşır, profil bilgisi paylaşır
- Kullanıcılar birbirine kişisel bilgi verebilir mi: EVET (mesajlaşma)
- Konum paylaşımı: hassas/gerçek-zamanlı konum paylaşımı **YOK** (yalnız kullanıcının beyan ettiği şehir görünür)
- Dijital satın alma: VAR (Premium abonelik)
- Beklenen sonuç: **18+ / Mature** — doğrudur, itiraz etme (RU 18 yaş onayı kayıtta zaten zorunlu)

## 2) Google Play — Data Safety formu
**Toplanan veriler (collected):**
- Kişisel bilgi: ad, telefon numarası, cinsiyet, yaş, şehir, bio/iş/eğitim (ops.), fotoğraflar (profil+selfie)
- Mesajlar: uygulama içi mesajlar (sunucuda saklanır)
- Konum: **yaklaşık konum** (şehir; konum izni yalnız şehir önerisi için — ops.)
- Uygulama etkinliği + tanılama: analitik olayları, çökme günlükleri
- Cihaz kimlikleri: push token, cihaz/uygulama tanımlayıcıları (Firebase, AppMetrica)

**Paylaşım (shared):** Analitik/çökme sağlayıcıları — Google Firebase (Analytics/Crashlytics/FCM) ve Yandex AppMetrica. Reklam amaçlı paylaşım YOK, veri satışı YOK.

**Güvenlik uygulamaları:**
- Aktarımda şifreleme (HTTPS): EVET
- Kullanıcı silme talep edebilir: **EVET — uygulama içi "Hesabı sil"** (GDPR kalıcı silme, 15.07 doğrulandı)
- Veriler isteğe bağlı mı: profil alanlarının bir kısmı ops., telefon/ad/foto/selfie zorunlu

## 3) App Store Connect — Age Rating anketi
- Cevaplar: şiddet/korku/tıbbi/kumar HAYIR · "Unrestricted Web Access" HAYIR
- **Dating: EVET** → otomatik **17+** çıkar; kabul et
- Sık/yoğun cinsel içerik veya çıplaklık: HAYIR (UGC moderasyonlu)

## 4) App Store Connect — App Privacy (Data Types)
Data safety ile aynı içerik, Apple taksonomisiyle:
- Contact Info: phone number, name · Photos: user photos · Location: coarse (ops.)
- User Content: messages, photos · Identifiers: device ID (analytics), push token
- Usage Data + Diagnostics: analytics, crash
- Hepsi "Linked to you" (hesaba bağlı); Tracking (ATT anlamında cross-app izleme): **HAYIR**

## 5) Apple UGC şartları (reviewer sorarsa)
Kullanıcı içeriği moderasyonu ✅: selfie zorunlu doğrulama · şikâyet (report) ✅ · engelleme (block, çift yönlü) ✅ · moderatör paneli + ban/askı zorlaması ✅ · 18+ yaş onayı kayıtta ✅

## Demo giriş (review formlarında zaten kayıtlı)
+7 000 000 00 01 / kod: 1234
