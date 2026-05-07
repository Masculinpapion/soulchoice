# SoulChoice — Claude Code Talimatları

## ⚠️ EN ÖNEMLİ: SUNUCU YEREL DEĞİL

Tüm Supabase backend Hetzner VPS'te self-hosted.
- SSH: root@178.104.199.93
- Domain: mybinancebot.duckdns.org
- 13 Docker container içinde

ASLA YAPMA:
- npx supabase komutları (yerel yok)
- psql 127.0.0.1 (Mac'te DB yok)
- supabase db execute --local
- cat supabase/.temp/* (yerel data yok)

HER ZAMAN YAP:
- SSH ile VPS'e bağlan
- Docker exec ile postgres'e eriş

## SQL ÇALIŞTIRMA

Tek satırlık:
```
ssh root@178.104.199.93 "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT * FROM users LIMIT 5;\""
```

Çok satırlık:
```
ssh root@178.104.199.93 'docker exec -i supabase-db psql -U postgres -d postgres' <<'EOF'
SELECT * FROM invitations WHERE status = 'active';
EOF
```

Container listesi:
```
ssh root@178.104.199.93 "docker ps --format '{{.Names}}'"
```

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
- Test user: Mustafa, +79295774238, OTP: 123456

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

## DEBUG KEYSTORE (CI İmza Tutarlılığı)

CI'da imza uyuşmazlığını önlemek için debug.keystore GitHub secret olarak tanımlanmalı.

**Secret adı:** `DEBUG_KEYSTORE_BASE64`

**Secret değeri:**
```
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
```

GitHub: Settings → Secrets → Actions → New repository secret

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

## Sunucu Bilgileri
- **Aktif Sunucu:** Timeweb (Moskova) — 89.169.1.127
- **SSH:** ssh -i ~/.ssh/hetzner_bot root@89.169.1.127
- **Domain:** https://soulchoice.app
- **Eski Sunucu:** Hetzner 178.104.199.93 (kullanılmıyor, yedek)
