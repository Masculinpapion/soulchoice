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

- API: https://mybinancebot.duckdns.org/rest/v1/
- Storage: https://mybinancebot.duckdns.org/storage/v1/
- Auth: https://mybinancebot.duckdns.org/auth/v1/

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
