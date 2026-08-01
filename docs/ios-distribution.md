# iOS + Android dağıtım kanalları (mağaza onayları öncesi)

**Durum: 01.08.2026 — hepsi CANLI.** Mağazalar tam yayına geçince "Kaldırma" bölümüne bak.

Apple, web sayfasından iPhone'a uygulama kurulmasına izin vermez (sideload yok).
Bu yüzden iOS'ta "tıkla-kur" deneyimine en yakın **meşru** yol TestFlight'tır.
Aşağıdaki üç kanal birlikte çalışır.

| Kanal | Adres | Kim için | Ölçek |
|---|---|---|---|
| TestFlight (iOS) | `testflight.apple.com/join/hHE6cCV6` | Herkes | Apple CDN, tester limiti kaldırıldı (tavan 10.000) |
| RuStore (Android) | `rustore.ru/catalog/app/com.soulchoice.soulchoice` | Herkes | Mağaza CDN |
| Doğrudan APK | `soulchoice.app/download/soulchoice.apk` | RuStore kullanmayan | 302 → GitHub Releases CDN |
| Web demo | `soulchoice.app/demo` → `/app/` | Kurmak istemeyen | Kendi sunucumuz (gzip'li ~1.4 MB) |
| Ad-hoc (kapalı) | `soulchoice.app/beta-private` | Kapalı ekip | 100 cihaz/yıl |

**Tek QR:** `soulchoice.app/get` — cihazı tanır, iOS'u TestFlight'a, Android'i
RuStore'a yollar. Afiş/sunum/sahne için tek kare yeter (`/img/qr-get.svg`).

---

## 1. TestFlight (iOS ana kanal)

Public link `testflight-link.yml` workflow'uyla yönetilir (elle App Store Connect
gerekmez):

```bash
gh workflow run testflight-link.yml        # veya Actions'tan "Run workflow"
# log'da: PUBLIC_LINK: https://testflight.apple.com/join/XXXX
```

- Grup: **Beta Testers** (external), ID `f2a2327f-4045-4a67-a5d8-51176a7b808c`.
- Tester limiti KAPALI (`publicLinkLimitEnabled: false`) → Apple tavanı 10.000.
- Her `main` push'unda CI yeni build'i bu gruba otomatik dağıtır
  (`ios-testflight.yml` → "Distribute to Beta Testers group").
- Yeni build'in testerlara düşmesi Apple işlemesi nedeniyle 5–15 dk sürer.

## 2. Android

**Birincil: RuStore** (yayında). **Yedek: doğrudan APK.**

APK'yı ELLE yüklemeyin — CI her `main` push'unda yayınlar
(`build.yml` → "Publish APK to landing download page"). Sunucudaki nginx kuralı
indirmeyi GitHub Releases CDN'ine 302'ler; origin başına yalnız ~154 bayt gider.

Zorunlu haldeyse elle:

```bash
# DİKKAT: build-number vermezsen versionCode=2 çıkar ve RuStore/CI sürümü kurulu
# cihazlarda INSTALL_FAILED_VERSION_DOWNGRADE alırsın (01.08'de yaşandı).
flutter build apk --release --build-number <son CI run numarasından büyük>
scp -i ~/.ssh/timeweb_prod build/app/outputs/flutter-apk/app-release.apk \
    root@89.169.1.127:/var/www/soulchoice/download/soulchoice.apk
```

## 3. Web demo (`/demo` → `/app/`)

Aynı Flutter kodu tarayıcıda koşar. Kurulum gerekmez; **push bildirimleri yoktur**.

```bash
flutter build web --release --no-wasm-dry-run --base-href /app/
# index.html'e noindex meta ekle (aksi halde Google demo'yu indeksler):
#   <meta name="robots" content="noindex, nofollow">
rsync -az --delete -e "ssh -i ~/.ssh/timeweb_prod" build/web/ \
      root@89.169.1.127:/var/www/soulchoice/app/
```

**Web-güvenlik katmanı (bozulursa beyaz ekran):**
- `main.dart`: Firebase/Crashlytics/AppMetrica/push `kIsWeb` ile atlanır.
- `core/utils/platform_x.dart`: `Platform.isIOS` web'de ÇAĞRILINCA fırlatır —
  doğrudan kullanma, `isIOSDevice` / `platformTag` kullan.
- `NativeUploader`: web'de Supabase storage'a düşer (selfie/foto adımı için şart).

## 4. Ad-hoc (kapalı ekip, yedek)

Sayfa: `soulchoice.app/beta-private` (hiçbir yerden linklenmez, `noindex`).
Kullanıcı UDID'sini yollar → cihaz Apple hesabına eklenir → imzalı `.ipa`
e-posta ile gider. Backend YOK: form hazır bir e-posta taslağı açar, kişisel veri
sitede saklanmaz.

```bash
# Cihazı kaydet (App Store Connect API — anahtar CI secret'larında)
# POST /v1/devices  {name, platform: IOS, udid}
# Sonra: provisioning profile'ı yenile → xcodebuild -exportArchive \
#        -exportOptionsPlist ad-hoc.plist → .ipa
```

Sınır: yılda 100 cihaz; her yeni cihaz grubunda profil yenileme + yeniden imza.
Bu yüzden **varsayılan kanal TestFlight'tır.**

## 5. QR üretimi

```bash
python3 -m venv /tmp/qrvenv && /tmp/qrvenv/bin/pip install segno
/tmp/qrvenv/bin/python -c "
import segno
segno.make('https://soulchoice.app/get', error='h').save(
    '/tmp/qr-get.svg', scale=10, border=2, dark='#ffffff', light=None)"
scp -i ~/.ssh/timeweb_prod /tmp/qr-get.svg root@89.169.1.127:/var/www/soulchoice/img/
```

`error='h'` = %30 hata toleransı: yansıtıcı ekranda/uzaktan da okunur.

## 6. Ölçek (kalabalık etkinlik) notları

- APK 69 MB: **asla origin'den servis etme** — 2 CPU / 3 GB sunucu binlerce
  eşzamanlı indirmede hem indirmeyi hem AYNI kutudaki API'yi düşürür.
  Kural: `/download/soulchoice.apk` → 302 → GitHub Releases.
- `/get` sayfası ~5,6 KB: 5.000 okutma ≈ 28 MB. Sorunsuz.
- Web demo gzip'li ~1,4 MB (sıkıştırmasız 5 MB'dı) — nginx `/app/` bloğunda
  `gzip on`. Kapatma.
- Yük testini **sunucunun üstünde** koşturma (01.08 dersi: 50 paralel curl
  yükü 15'e çıkardı, API 13 sn'ye yavaşladı). Dışarıdan ve ölçülü test et.

## Kaldırma (mağazalar tam yayına geçince)

1. Landing'de `<section id="beta">` bloğunu sil (yedek:
   `/root/landing-baks/index.html.bak-*`).
2. Hero + CTA'daki store butonlarını gerçek mağaza linklerine çevir
   (şu an App Store butonu `#download` çapası, Google Play butonu APK'ya gidiyor).
3. `/get`, `/beta-private`, `/app/` yolları kalabilir (demo faydalı) —
   istenirse nginx'ten kaldır.
