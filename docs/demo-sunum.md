# Sunum akışı — hoca + arkadaşlar (01.08.2026 sabahı)

**Amaç:** 4 ayda kurulan sistemi 5-7 dakikada, hiçbir şeyi uydurmadan, doğrulanabilir
şekilde göstermek. Her adımın altında "ne diyeceksin" var.

## 0 · Sunumdan 10 dk önce (kontrol)
```bash
bash tests/security/smoke.sh                 # 13 yüzey reddediyor mu
~/.deno/bin/deno test --allow-read --allow-env tests/edge/
curl -s -o /dev/null -w '%{http_code}\n' https://soulchoice.app/get
```
Telefonunda uygulamayı bir kez aç (soğuk açılış hızlı olsun), Wi-Fi'a bağlan.

## 1 · Kanca: "Bu uygulama şu an yayında" (30 sn)
- RuStore sayfasını aç: `rustore.ru/catalog/app/com.soulchoice.soulchoice` — **5,0★, canlı**.
- Cümle: *"Bu bir prototip değil; Rusya'nın resmi uygulama mağazasında yayında."*

## 2 · Salondakiler uygulamayı kursun (1 dk)
- Ekrana **QR** ver: `soulchoice.app/get` (veya landing'deki BETA bölümü).
- iPhone'lular TestFlight'tan, Android'liler RuStore'dan kurar; kurmak istemeyen
  **tarayıcıda** açar (`soulchoice.app/demo`).
- Cümle: *"iOS'ta web'den kurulum Apple tarafından yasak; bu yüzden Apple'ın resmi
  beta kanalı TestFlight'ı kullanıyoruz — tek dokunuşla kuruluyor."*
  (Bu cümle seni teknik olarak bilen birinin gözünde yükseltir.)

## 3 · Ürünü canlı göster (2 dk)
Telefondan sırayla: **feed → davet aç → başvur → seç → sohbet**.
Vurgu: her profil selfie ile doğrulanmış; davetler 6–48 saat yaşıyor; eşleşme
olmadan mesaj yok.

## 4 · Mühendislik tarafı — asıl fark burada (2 dk)
Ops panelini aç (mTLS + TOTP çift kilit) ve şunları göster:
- **Canlı nabız:** şehir kartları, o an online kullanıcılar.
- **Ödeme & Abonelik sekmesi:** gerçek banka entegrasyonu (Точка), abonelik
  durumları, ödeme geçmişi.
- Cümle: *"Ödeme, abonelik yenileme, başarısız çekim kurtarma ve **iade mutabakatı**
  uçtan uca otomatik. Banka bir iadeyi işlerse sistem bunu kendi buluyor,
  premium'u kapatıyor ve bir daha çekim yapmıyor."*

## 5 · Güvenlik ve kalite (1 dk) — jüri/hoca bunu sever
- 31.07'de yapılan sistematik denetimde **40+ bulgu** kapatıldı (giriş gerektirmeyen
  yönetim uçları, telefon/e-posta sızıntısı, zorla eşleşme, çifte çekim…).
- Bugün **CI'da her push'ta koşan otomatik testler** kuruldu: para mantığı unit
  testleri + veritabanı sözleşme testi + **13 korumalı yüzeyi anon anahtarla
  deneyen güvenlik smoke testi** (günlük de koşuyor).
- İstersen canlı çalıştır: `bash tests/security/smoke.sh` — ekranda 13 satır ✅.
- Cümle: *"Güvenliği insan hafızasına bırakmıyoruz; her push'ta makine sınıyor."*

## 6 · (Opsiyonel) Canlı ödeme demosu — en çarpıcı an
Gerçek para, küçük tutar. Sahnede yapılır:
1. Uygulamada Premium ekranını aç → ödeme bağlantısı.
2. **1-2₽'lik gerçek işlem** (`TEST_PAYMENT_KEY` ile test tutarı; banka gerçek).
3. Ödeme onayı → webhook → **premium saniyeler içinde açılır**, ekranda görünür.
- Cümle: *"Şu anda gerçek bir para hareketi oldu ve sistem saniyeler içinde işledi."*
- ⚠️ Sahte tutar/sahte kayıt YOK. Küçük ama gerçek işlem, uydurma büyük rakamdan
  her zaman daha ikna edicidir — çünkü doğrulanabilir.

## 7 · Kapanış (30 sn)
"4 ay: Flutter + self-hosted Supabase, iki mağaza süreci, gerçek ödeme altyapısı,
sistematik güvenlik denetimi ve otomatik test kapısı. Sırada: reklamla ilk
kullanıcı dalgası."

---

## ⚠️ Sunumdan önce bilmen gereken iki sınır
1. **Kayıt yalnız +7 (Rusya) numarası kabul ediyor.** Yabancı numaralı biri kayıt
   olamaz. Salonda Türk/başka numaralı arkadaşların varsa onlara **tarayıcı demosu**
   ya da mağaza-inceleme demo hesabı ver: `+7 000 000 00 01`, kod `1234`.
2. **iOS'ta ödeme ekranı kapalı** (App Store 3.1.1 gereği). Ödeme demosunu
   **Android telefondan veya tarayıcıdan** yap.

## Reklama (UGC) başlamadan önce — kısa hazırlık listesi
- [ ] Kayıt kapısı: +7 dışı numaralar reddediliyor → reklam hedeflemesi **yalnız
      Rusya** olmalı; aksi halde tıklama başına para yakarsın.
- [ ] Trafik hazırlığı tamam: APK GitHub CDN'inden iniyor, web demosu sıkıştırılmış,
      `/get` 5,6 KB (bkz. `docs/ios-distribution.md` §6).
- [ ] İzleme açık: Telegram alarmları + günlük billing digest + uptime kontrolü.
- [ ] İlk dalga sonrası bak: kayıt→selfie onayı→ilk davet dönüşüm oranları
      (ops panel Analitik sekmesi).
