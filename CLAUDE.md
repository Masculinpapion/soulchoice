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

## KURAL

Her bug fix öncesi:
1. View ile dosyayı oku
2. Grep ile satırı bul
3. str_replace ile düzelt
4. kill -SIGUSR2 ile hot restart
5. adb ile test et
