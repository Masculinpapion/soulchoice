#!/usr/bin/env bash
# /root/monitoring/checks.sh — sağlık kontrolleri.
# Crontab: */15 dk normal koşu; 08:05 UTC "billing" argümanıyla günlük billing-cron denetimi.
# Alarm politikası: durum DEĞİŞİNCE mesaj (spam yok); süren CRIT için günde 1 hatırlatma.
set -u
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

DIR=/root/monitoring
STATE=$DIR/state
mkdir -p "$STATE"
ALERT=$DIR/alert.sh

# Önce kuyruktaki gönderilememiş alarmları dene (Telegram kesintisi telafisi)
$ALERT --flush

report() { # report <ad> <OK|WARN|CRIT> <mesaj>
  local name=$1 status=$2 msg=$3
  local f="$STATE/$name"
  local prev="OK"; [ -f "$f" ] && prev=$(cat "$f")
  if [ "$status" != "$prev" ]; then
    if [ "$status" = "OK" ]; then
      $ALERT OK "$name düzeldi: $msg"
      rm -f "$f" "$STATE/$name.reminded"
    else
      $ALERT "$status" "$name: $msg"
      echo "$status" > "$f"
    fi
  elif [ "$status" = "CRIT" ]; then
    local stamp="$STATE/$name.reminded"
    if [ ! -f "$stamp" ] || [ "$(date +%F)" != "$(cat "$stamp")" ]; then
      $ALERT CRIT "$name SÜRÜYOR: $msg"
      date +%F > "$stamp"
    fi
  fi
}

# --- Günlük billing-cron denetimi (sadece "billing" argümanıyla) ---
if [ "${1:-}" = "billing" ]; then
  LOG=/var/log/billing-cron.log
  TODAY=$(date -I)
  if ! grep -q "=== ${TODAY}" "$LOG" 2>/dev/null; then
    report billing CRIT "bugünkü billing-cron koşusu log'da YOK ($LOG)"
  elif grep "${TODAY}" "$LOG" | grep -qi "SKIP"; then
    report billing WARN "billing-cron bugün SKIP etti (önceki koşu bitmemiş)"
  elif awk "/=== ${TODAY}/{found=1} found" "$LOG" | grep -q "curl:"; then
    report billing CRIT "billing-cron curl hatası — log'a bak: $LOG"
  else
    report billing OK "bugünkü koşu temiz"
  fi
  exit 0
fi

# --- 1. Disk doluluk ---
USE=$(df --output=pcent / | tail -1 | tr -dc '0-9')
if [ "$USE" -ge 92 ]; then report disk CRIT "kök disk %${USE} dolu"
elif [ "$USE" -ge 85 ]; then report disk WARN "kök disk %${USE} dolu"
else report disk OK "disk %${USE}"
fi

# --- 2. Yedek tazeliği ---
NEWEST=$(ls -t /root/backups/db_*.sql.gz 2>/dev/null | head -1)
if [ -z "$NEWEST" ]; then
  report backup CRIT "hiç DB yedeği yok (/root/backups)"
else
  AGE_H=$(( ( $(date +%s) - $(stat -c %Y "$NEWEST") ) / 3600 ))
  AGE_MIN=$(( ( $(date +%s) - $(stat -c %Y "$NEWEST") ) / 60 ))
  SIZE=$(stat -c %s "$NEWEST")
  if [ "$AGE_H" -gt 27 ]; then report backup CRIT "son DB yedeği ${AGE_H} saat eski ($(basename "$NEWEST"))"
  elif [ "$SIZE" -lt 102400 ]; then
    # 03:00 cron'u hâlâ yazıyor olabilir — 30 dk'dan taze küçük dosya alarm DEĞİL
    # (her sabah 06:00-06:30 MSK sahte KRİTİK+düzeldi çifti üretiyordu, 31.07)
    [ "$AGE_MIN" -ge 30 ] && report backup CRIT "son DB yedeği şüpheli küçük (${SIZE} bayt, $(basename "$NEWEST"))"
  else report backup OK "$(basename "$NEWEST"), ${AGE_H} saat"
  fi
fi

# --- 2b. Off-site yedek (Yandex Object Storage) ---
OFF_LOG=/root/backups/offsite/last-run.log
if [ ! -f "$OFF_LOG" ]; then
  report offsite CRIT "off-site yedek hiç çalışmadı (log yok)"
else
  OFF_AGE_H=$(( ( $(date +%s) - $(stat -c %Y "$OFF_LOG") ) / 3600 ))
  OFF_AGE_MIN=$(( ( $(date +%s) - $(stat -c %Y "$OFF_LOG") ) / 60 ))
  if ! grep -q "done .* OK" "$OFF_LOG"; then
    # 04:00 yüklemesi sürüyor olabilir — log 30 dk'dan tazeyse alarm verme (sabah sahte KRİTİK fix'i)
    [ "$OFF_AGE_MIN" -lt 30 ] || report offsite CRIT "son off-site yükleme BAŞARISIZ (log sonunda done OK yok)"
  elif [ "$OFF_AGE_H" -gt 27 ]; then
    report offsite CRIT "son off-site yükleme ${OFF_AGE_H} saat eski"
  else
    report offsite OK "off-site güncel (${OFF_AGE_H} saat)"
  fi
fi

# --- 3. Web + functions health ---
CODE_WEB=$(curl -s -o /dev/null -m 15 -w "%{http_code}" https://soulchoice.app/ || echo 000)
if [ "$CODE_WEB" = "200" ]; then report web OK "soulchoice.app 200"
else report web CRIT "soulchoice.app HTTP ${CODE_WEB}"
fi

CODE_FN=$(curl -s -o /dev/null -m 15 -w "%{http_code}" https://soulchoice.app/functions/v1/hello || echo 000)
case "$CODE_FN" in
  200|401) report functions OK "functions ucu ${CODE_FN}" ;;
  *)       report functions CRIT "functions ucu HTTP ${CODE_FN}" ;;
esac

# --- 4. Kritik container'lar ---
MISSING=""
for c in supabase-db supabase-kong supabase-auth supabase-rest supabase-edge-functions supabase-storage; do
  docker ps --format '{{.Names}}' | grep -qx "$c" || MISSING="$MISSING $c"
done
if [ -n "$MISSING" ]; then report containers CRIT "çalışmayan container:${MISSING}"
else report containers OK "6/6 kritik container ayakta"
fi

# --- 5. SMS.ru bakiye (OTP hattı) ---
# Kaynak: ops-agent tabstats (127.0.0.1:9700, localhost-only). Eşikler panelle
# hizalı: <2000 ₽ WARN (SMS.ru e-posta uyarısıyla aynı), <200 ₽ CRIT (kayıt durabilir).
BAL=$(curl -s -m 10 http://127.0.0.1:9700/api/tabstats | jq -r ".otp.smsruBalance // empty")
if ! [[ "$BAL" =~ ^[0-9]+$ ]]; then
  report smsbalance WARN "SMS.ru bakiyesi okunamadı (agent tabstats cevabı: ${BAL:-boş})"
elif [ "$BAL" -lt 1000 ]; then
  report smsbalance CRIT "SMS.ru bakiye ${BAL} ₽ (<1000) — kayıt durabilir, HEMEN yükle (sms.ru → Пополнить)"
elif [ "$BAL" -lt 3000 ]; then
  report smsbalance WARN "SMS.ru bakiye ${BAL} ₽ (<3000) — yükleme planla"
else
  report smsbalance OK "SMS.ru bakiye ${BAL} ₽"
fi

# --- 5b. SMS.ru KAPASİTE (02.09.2026, Mustafa: limit olmasın, para bitmeden uyar) ---
# a) Günlük farklı-numara limiti: sms.ru hesabında 10 idi, 5 ay fark edilmedi.
#    <1000 → WARN (durum değişince 1 kez), kullanım ≥%80 → CRIT (kayıt kesilmek üzere).
# b) Erime hızı → kalan süre: son 60 dk harcamadan "kaç saat kaldı" hesaplanır;
#    <2 saat → CRIT (kampanya gününde bakiye 2 saat sonra biter demek).
SMSKEY=$(grep "^SMS_RU_API_KEY=" /root/supabase/docker/.env | cut -d= -f2-)
LIM=$(curl -s -m 10 "https://sms.ru/my/limit?api_id=${SMSKEY}&json=1")
LIMTOT=$(echo "$LIM" | jq -r '.total_limit // empty'); LIMUSED=$(echo "$LIM" | jq -r '.used_today // empty')
if [[ "$LIMTOT" =~ ^[0-9]+$ ]] && [[ "$LIMUSED" =~ ^[0-9]+$ ]]; then
  if [ "$LIMTOT" -gt 0 ] && [ $(( LIMUSED * 100 / LIMTOT )) -ge 80 ]; then
    report smslimit CRIT "SMS.ru günlük numara limiti doluyor: ${LIMUSED}/${LIMTOT} — yeni kayıtların SMS'i KESİLECEK (sms.ru → Увеличить лимит)"
  elif [ "$LIMTOT" -lt 1000 ]; then
    report smslimit WARN "SMS.ru günlük farklı-numara limiti ${LIMTOT} (bugün ${LIMUSED}) — reklam günü yetmez, artırma başvurusu yap"
  else
    report smslimit OK "SMS.ru günlük limit ${LIMTOT}, bugün ${LIMUSED}"
  fi
else
  report smslimit WARN "SMS.ru limit bilgisi okunamadı (my/limit cevabı: $(echo "$LIM" | tr -d '\n' | cut -c1-80))"
fi
# Erime hızı: 60 dk önceki bakiye (state dosyası saat damgalı) ile karşılaştır
if [[ "$BAL" =~ ^[0-9]+$ ]]; then
  HRF="$STATE/smsbalance.hour"   # içerik: "<epoch> <bakiye>"
  NOW=$(date +%s)
  if [ -f "$HRF" ]; then
    read -r HT HB < "$HRF"
    AGE=$(( NOW - HT ))
    if [ "$AGE" -ge 3600 ]; then
      SPENT=$(( HB - BAL ))
      if [ "$SPENT" -gt 0 ]; then
        RATE=$(( SPENT * 3600 / AGE ))          # ₽/saat
        HOURS_LEFT=$(( RATE > 0 ? BAL / RATE : 999 ))
        if [ "$HOURS_LEFT" -lt 2 ]; then
          report smsburn CRIT "SMS.ru bakiye ${BAL} ₽, saatte ${RATE} ₽ eriyor → ~${HOURS_LEFT} saat kaldı — HEMEN yükle"
        elif [ "$HOURS_LEFT" -lt 6 ]; then
          report smsburn WARN "SMS.ru bakiye ${BAL} ₽, saatte ${RATE} ₽ → ~${HOURS_LEFT} saat kaldı — yükleme planla"
        else
          report smsburn OK "SMS.ru erime hızı ${RATE} ₽/saat, ~${HOURS_LEFT} saat"
        fi
      else
        report smsburn OK "SMS.ru son saatte harcama yok"
      fi
      echo "$NOW $BAL" > "$HRF"
    fi
  else
    echo "$NOW $BAL" > "$HRF"
  fi
fi

# --- 6. RAM + yük (2 vCPU / 3.9 GB; OOM riski) ---
read -r MT MA <<< "$(free -m | awk 'NR==2{print $2, $7}')"
if [ -n "${MT:-}" ] && [ "$MT" -gt 0 ]; then
  RPCT=$(( MA * 100 / MT ))
  if [ "$RPCT" -le 7 ]; then report ram CRIT "kullanılabilir RAM %${RPCT} (${MA} MB) — OOM riski"
  elif [ "$RPCT" -le 15 ]; then report ram WARN "kullanılabilir RAM %${RPCT} (${MA} MB)"
  else report ram OK "RAM %${RPCT} boş"
  fi
fi
LOAD5=$(awk '{printf "%d", $2+0.5}' /proc/loadavg)
if [ "$LOAD5" -ge 8 ]; then report load CRIT "load5=${LOAD5} (2 vCPU) — CPU boğuldu"
elif [ "$LOAD5" -ge 4 ]; then report load WARN "load5=${LOAD5} (2 vCPU)"
else report load OK "load5=${LOAD5}"
fi

# --- 7. DB bağlantı doluluğu (max_connections=100, boşta ~43) ---
CONN=$(docker exec supabase-db psql -U postgres -Atc "select count(*) from pg_stat_activity" 2>/dev/null)
if ! [[ "$CONN" =~ ^[0-9]+$ ]]; then report dbconn WARN "pg_stat_activity okunamadı"
elif [ "$CONN" -ge 90 ]; then report dbconn CRIT "DB bağlantısı ${CONN}/100 — havuz tükenmek üzere"
elif [ "$CONN" -ge 70 ]; then report dbconn WARN "DB bağlantısı ${CONN}/100"
else report dbconn OK "DB bağlantısı ${CONN}/100"
fi

# --- 8. API sağlığı: DB'den GERÇEK okuma (statik 200 kör noktasına karşı) ---
# anon key public istemci anahtarı (APK'da da var); dosyadan okunur, header şart
# (query-param apikey PostgREST'te filter sanılıyor — 400).
ANONK=$(cat /root/monitoring/anon.key 2>/dev/null)
APIC=$(curl -s -o /dev/null -m 15 -w "%{http_code}" -H "apikey: ${ANONK}" "https://soulchoice.app/rest/v1/cities?select=id&limit=1" || echo 000)
if [ "$APIC" = "200" ]; then report api OK "rest/v1 DB okuma 200"
else report api CRIT "rest/v1 DB okuma HTTP ${APIC} — API/DB hattı sorunlu (statik site yeşil olabilir!)"
fi

# --- 9. OTP hattı: bakiye erime hızı + bekleyen yığılması ---
# 5. bölümdeki $BAL kullanılır. 15 dk'da ≥300 ₽ düşüş (≈75 SMS) → viral yük ya da SMS pumping.
if [[ "${BAL:-}" =~ ^[0-9]+$ ]]; then
  LASTF="$STATE/smsbalance.lastval"
  if [ -f "$LASTF" ]; then
    DROP=$(( $(cat "$LASTF") - BAL ))
    if [ "$DROP" -ge 300 ]; then
      # 25.07: markali gonderici-adi aylik aboneligi de buyuk dusus yapar (used_today=0).
      # SMS.ru bugunku gonderim sayisi sorulur: yuksekse pumping, ~0 ise abonelik ucreti.
      SMSKEY=$(grep "^SMS_RU_API_KEY=" /root/supabase/docker/.env | cut -d= -f2-)
      USEDTODAY=$(curl -s -m 10 "https://sms.ru/my/limit?api_id=${SMSKEY}&json=1" | jq -r ".used_today // empty")
      if [[ "$USEDTODAY" =~ ^[0-9]+$ ]] && [ "$USEDTODAY" -lt 20 ]; then
        report smsdrain OK "bakiye ${DROP} RUB dustu ama bugun ${USEDTODAY} SMS - abonelik/gonderici-adi ucreti, pumping degil"
      else
        report smsdrain WARN "SMS.ru bakiye 15 dk ${DROP} RUB eridi, bugun ${USEDTODAY:-?} SMS - viral yuk/pumping OLABILIR"
      fi
    else report smsdrain OK "bakiye erimesi normal"
    fi
  fi
  echo "$BAL" > "$LASTF"
fi
PEND=$(docker exec supabase-db psql -U postgres -Atc "select pending_otps from v_otp_stats" 2>/dev/null)
if [[ "$PEND" =~ ^[0-9]+$ ]]; then
  if [ "$PEND" -ge 10 ]; then report otppile WARN "aktif bekleyen OTP ${PEND} — SMS teslimatı aksıyor olabilir"
  else report otppile OK "bekleyen OTP ${PEND}"
  fi
fi

# --- 10. Container yeniden başlama tespiti ('Up 2 min' de yeşil görünür, flap kaçar) ---
RESTARTED=""
for c in supabase-db supabase-kong supabase-auth supabase-rest supabase-edge-functions supabase-storage; do
  SA=$(docker inspect -f '{{.State.StartedAt}}' "$c" 2>/dev/null)
  [ -z "$SA" ] && continue
  F="$STATE/started.$c"
  if [ -f "$F" ] && [ "$(cat "$F")" != "$SA" ]; then RESTARTED="$RESTARTED $c"; fi
  echo "$SA" > "$F"
done
# Planlı deploy bastırması (madde W, 31.07): CI push'u edge function dosyalarını
# yazıp container'ı restart eder — functions klasörü son 20 dk'da değiştiyse
# edge-functions restart'ı PLANLI say, uyarma (dün 8 push = 8 gereksiz uyarı).
# Gerçek çökme döngüsünü 13. kontrol (unhealthy oto-onarım) zaten yakalar.
if [[ "$RESTARTED" == *supabase-edge-functions* ]]; then
  FN_FRESH=$(find /root/volumes/functions -type f -mmin -20 2>/dev/null | head -1)
  [ -n "$FN_FRESH" ] && RESTARTED=$(echo "$RESTARTED" | sed 's/ supabase-edge-functions//')
fi
[ -n "${RESTARTED// /}" ] && $ALERT WARN "container yeniden başladı:$RESTARTED"

# --- 11. TLS kalan gün (certbot sessiz kırılırsa 90 gün içinde site düşer) ---
EXPD=$(echo | openssl s_client -connect soulchoice.app:443 -servername soulchoice.app 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$EXPD" ]; then
  TDAYS=$(( ( $(date -d "$EXPD" +%s) - $(date +%s) ) / 86400 ))
  if [ "$TDAYS" -le 7 ]; then report tls CRIT "TLS sertifikası ${TDAYS} gün sonra bitiyor"
  elif [ "$TDAYS" -le 14 ]; then report tls WARN "TLS sertifikası ${TDAYS} gün sonra bitiyor"
  else report tls OK "TLS ${TDAYS} gün geçerli"
  fi
else report tls WARN "TLS bitiş tarihi okunamadı"
fi

# --- 12. Kayıt patlaması (iyi haber erken uyarısı; 6 saatte en çok 1 mesaj) ---
REG1H=$(docker exec supabase-db psql -U postgres -Atc "select count(*) from users where created_at > now() - interval '1 hour'" 2>/dev/null)
if [[ "$REG1H" =~ ^[0-9]+$ ]] && [ "$REG1H" -ge 20 ]; then
  RSTAMP="$STATE/regburst.stamp"
  NOWS=$(date +%s)
  if [ $(( NOWS - $(cat "$RSTAMP" 2>/dev/null || echo 0) )) -ge 21600 ]; then
    $ALERT INFO "🚀 kayıt patlaması: son 1 saatte ${REG1H} yeni kayıt — kaynakları izle (RAM/DB bağlantı/bakiye)"
    echo "$NOWS" > "$RSTAMP"
  fi
fi

# --- 13. Otomatik onarım: çökmüş/unhealthy container restart (19.07.2026) ---
# Politika: restart sonrası 30 dk içinde yine sorunluysa veya 24 saatte 3+ kez
# gerekiyorsa otomatik restart DURUR ve CRIT verilir — döngüyü maskeleme.
for c in supabase-db supabase-kong supabase-auth supabase-rest supabase-edge-functions supabase-storage supabase-realtime; do
  CST=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null) || continue
  CHL=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$c" 2>/dev/null)
  if [ "$CST" != "running" ] || [ "$CHL" = "unhealthy" ]; then
    RLOG="$STATE/autorestart.$c"
    NOWS=$(date +%s)
    RECENT=$(awk -v now="$NOWS" '$1 > now-86400' "$RLOG" 2>/dev/null | wc -l)
    LASTR=$(tail -1 "$RLOG" 2>/dev/null); LASTR=${LASTR:-0}
    if [ "$RECENT" -ge 3 ]; then
      report "autorestart_$c" CRIT "$c 24 saatte ${RECENT}. kez sorunlu (durum=$CST/${CHL:--}) — oto-restart DURDU, elle bak"
    elif [ $(( NOWS - LASTR )) -lt 1800 ]; then
      report "autorestart_$c" CRIT "$c restart sonrası 30 dk içinde yine sorunlu (durum=$CST/${CHL:--}) — elle bak"
    else
      docker restart "$c" >/dev/null 2>&1
      sleep 10
      CST2=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null)
      echo "$NOWS" >> "$RLOG"
      if [ "$CST2" = "running" ]; then
        $ALERT WARN "🔧 oto-onarım: $c ${CST}/${CHL:--} idi → restart edildi, şu an running"
      else
        report "autorestart_$c" CRIT "$c oto-restart BAŞARISIZ (durum=${CST2:-yok})"
      fi
    fi
  else
    # düzelmişse eski CRIT durumunu kapat
    [ -f "$STATE/autorestart_$c" ] && report "autorestart_$c" OK "$c sağlıklı"
  fi
done

# --- 14. RuStore yayin tespiti (25.07.2026, lansman madde I) ---
# Moderasyon onaylaninca genel katalog sayfasi 404 -> 200 olur (25.07 baseline: 404).
# Tek seferlik mujde alarmi: state dosyasi yazilinca bir daha kontrol edilmez.
RS_STAMP="$STATE/rustore-live"
if [ ! -f "$RS_STAMP" ]; then
  RS_CODE=$(curl -s -o /dev/null -m 15 -w "%{http_code}" "https://www.rustore.ru/catalog/app/com.soulchoice.soulchoice" || echo 000)
  if [ "$RS_CODE" = "200" ]; then
    $ALERT INFO "🚀 RuStore YAYINDA — moderasyon onaylandi, sayfa canli: https://www.rustore.ru/catalog/app/com.soulchoice.soulchoice"
    date -Is > "$RS_STAMP"
  fi
fi

# --- 15. OTP SMS_FAILED patlamasi (11.08.2026) ---
# send-call-otp ret sebebini logluyor (SMS_FAILED + SMS.ru cevabi). Yabanci
# numaralar artik 400 unsupported_region aliyor ve buraya DUSMEZ; yani bu
# sayac >=3 ise gercek +7 kullanicilari kod alamiyor demektir (limit/rota/bakiye).
SF_COUNT=$(docker logs supabase-edge-functions --since 15m 2>&1 | grep -c "send-call-otp SMS_FAILED" || true)
if [ "${SF_COUNT:-0}" -ge 3 ]; then
  SF_LAST=$(docker logs supabase-edge-functions --since 15m 2>&1 | grep "send-call-otp SMS_FAILED" | tail -1 | cut -c1-280)
  report "otp_smsfail" CRIT "OTP: 15 dk icinde $SF_COUNT SMS reddi — gercek kullanici kod alamiyor olabilir. Son sebep: $SF_LAST"
else
  [ -f "$STATE/otp_smsfail" ] && report "otp_smsfail" OK "SMS gonderimi normale dondu"
fi

# --- 16. Nobetci Kovan: istemci hata patlamasi (12.08.2026) ---
# client_errors tablosuna app icinden sessiz hatalar dusuyor (log-client-error).
# 15 dk icinde >=5 kayit = kullanicilar bir seye tosluyor -> CRIT + en sik hata.
CE_COUNT=$(docker exec supabase-db psql -U postgres -t -A -c "select count(*) from client_errors where created_at > now() - interval '15 minutes' and platform <> 'test'" 2>/dev/null | head -1)
if [ "${CE_COUNT:-0}" -ge 5 ] 2>/dev/null; then
  CE_TOP=$(docker exec supabase-db psql -U postgres -t -A -c "select left(error,140)||' ('||count(*)||'x, ekran: '||coalesce(nullif(screen,''),'?')||')' from client_errors where created_at > now() - interval '15 minutes' and platform <> 'test' group by left(error,140), screen order by count(*) desc limit 1" 2>/dev/null | head -1)
  report "kovan_client_errors" CRIT "Kovan: 15 dk'da $CE_COUNT istemci hatasi. En sik: ${CE_TOP:-?}"
else
  [ -f "$STATE/kovan_client_errors" ] && report "kovan_client_errors" OK "istemci hata akisi normale dondu"
fi

# --- 17. Hediye metin moderasyon kuyrugu (20.08.2026, Mustafa karari) ---
# Beyaz-liste linkleri artik otomatik onaylanir (enforce_gift_link); kuyruga
# yalniz SERBEST METIN girisleri duser -> panel basinda beklemeye gerek yok,
# kuyruk dolunca Telegram haber verir, bosalinca "duzeldi" gelir.
GQ_COUNT=$(docker exec supabase-db psql -U postgres -t -A -c "select count(*) from invitation_gift_links where status='pending'" 2>/dev/null | head -1)
if [ "${GQ_COUNT:-0}" -ge 1 ] 2>/dev/null; then
  report "gift_moderation_queue" WARN "Hediye moderasyonu: $GQ_COUNT metin onay bekliyor -> ops paneli / Hediye karti"
else
  [ -f "$STATE/gift_moderation_queue" ] && report "gift_moderation_queue" OK "hediye kuyrugu bos"
fi

# --- 18. DDoS koruma DNS nobeti (29.08.2026, Mustafa onayi) ---
# soulchoice.app/www A kaydi korumali IP'den (104.171.129.167) saparsa site
# calisir ama KORUMASIZ kalir -> sessiz risk. Imza (server: ddos-guard)
# kontrolu sunucudan YAPILAMAZ (Timeweb ic agi DDG'ye cikmiyor, origin direkt
# cevap veriyor) -> imza nobeti dis gozlemcide (soulchoice-ops uptime.yml).
DDG_IP="104.171.129.167"
DDG_A1=$(dig +short @8.8.8.8 soulchoice.app A 2>/dev/null | head -1)
DDG_A2=$(dig +short @8.8.8.8 www.soulchoice.app A 2>/dev/null | head -1)
if [ -n "$DDG_A1" ] && { [ "$DDG_A1" != "$DDG_IP" ] || [ "$DDG_A2" != "$DDG_IP" ]; }; then
  report "ddg_dns_guard" WARN "DDoS korumasi: DNS korumali IP'den sapmis gorunuyor (apex=$DDG_A1 www=$DDG_A2, beklenen $DDG_IP) — site korumasiz olabilir!"
else
  [ -f "$STATE/ddg_dns_guard" ] && report "ddg_dns_guard" OK "DNS yeniden korumali IP'de"
fi

# --- 19. Edge/API 5xx patlamasi (03.09.2026, kalite teshisi B1) ---
# kong access log'unda son 15 dk 5xx sayisi. Baz cizgi: 24 saatte 0.
K5=$(docker logs supabase-kong --since 15m 2>&1 | grep -cE '" 5[0-9]{2} ' || true)
if [ "${K5:-0}" -ge 20 ]; then report "api_5xx" CRIT "API: 15 dk'da $K5 adet 5xx (kong). Son: $(docker logs supabase-kong --since 15m 2>&1 | grep -E '" 5[0-9]{2} ' | tail -1 | cut -c1-160)"
elif [ "${K5:-0}" -ge 5 ]; then report "api_5xx" WARN "API: 15 dk'da $K5 adet 5xx (kong)"
else [ -f "$STATE/api_5xx" ] && report "api_5xx" OK "5xx normale dondu"
fi

# --- 20. Odeme webhook hatasi (03.09.2026, B7) ---
# tochka-webhook yalniz console.error yaziyordu, alarm yoktu. 15 dk'da 1 hata = CRIT (para).
TW=$(docker logs supabase-edge-functions --since 15m 2>&1 | grep -cE "tochka-webhook error|tochka verify unavailable|paid but no users profile|subscription op without local record" || true)
if [ "${TW:-0}" -ge 1 ]; then
  TW_LAST=$(docker logs supabase-edge-functions --since 15m 2>&1 | grep -E "tochka-webhook error|tochka verify unavailable|paid but no users profile|subscription op without local record" | tail -1 | cut -c1-200)
  report "tochka_webhook" CRIT "Odeme webhook'unda $TW hata (15 dk). Son: $TW_LAST"
else
  [ -f "$STATE/tochka_webhook" ] && report "tochka_webhook" OK "webhook temiz"
fi

# --- 21. OTP donusum orani + tavan (03.09.2026, B2) ---
# otp_send_log.result: sent / verified / wrong / too_many / fail:*. Son 60 dk gonderim >=10 ve
# dogrulama/gonderim < %50 = kullanicilar kod alamiyor veya giremiyor -> CRIT.
OTP_ROW=$(docker exec supabase-db psql -U postgres -t -A -c "select count(*) filter (where result='sent'), count(*) filter (where result='verified'), count(*) filter (where result like 'fail:%') from otp_send_log where created_at > now() - interval '60 minutes'" 2>/dev/null | head -1)
OTP_SENT=${OTP_ROW%%|*}; OTP_REST=${OTP_ROW#*|}; OTP_VER=${OTP_REST%%|*}; OTP_FAIL=${OTP_REST#*|}
if [ "${OTP_SENT:-0}" -ge 10 ] 2>/dev/null && [ $(( ${OTP_VER:-0} * 100 / OTP_SENT )) -lt 50 ]; then
  report "otp_conversion" CRIT "OTP: 60 dk'da $OTP_SENT gonderim, yalniz $OTP_VER dogrulama, $OTP_FAIL ret — kullanicilar kod alamiyor/giremiyor olabilir"
else
  [ -f "$STATE/otp_conversion" ] && report "otp_conversion" OK "OTP donusumu normal ($OTP_VER/$OTP_SENT)"
fi
OTP_CAP=$(docker logs supabase-edge-functions --since 15m 2>&1 | grep -c "send-call-otp OTP_CAP\|STORE_CAP" || true)
if [ "${OTP_CAP:-0}" -ge 3 ]; then report "otp_cap" WARN "OTP: 15 dk'da $OTP_CAP tavan reddi (numara basina 15/24s) — saldiri veya takilan kullanici"
else [ -f "$STATE/otp_cap" ] && report "otp_cap" OK "tavan reddi yok"
fi

# --- 22. Push teslim orani (03.09.2026, B3) ---
# push_log.status (send-notification yazar). 60 dk'da >=10 denemede basarisiz oran >%40 CRIT, >%20 WARN.
PL_ROW=$(docker exec supabase-db psql -U postgres -t -A -c "select count(*) filter (where status is not null), count(*) filter (where status in ('unregistered','fcm_fail','rustore_fail')) from push_log where sent_at > now() - interval '60 minutes'" 2>/dev/null | head -1)
PL_TOT=${PL_ROW%%|*}; PL_BAD=${PL_ROW#*|}
if [ "${PL_TOT:-0}" -ge 10 ] 2>/dev/null; then
  PL_PCT=$(( ${PL_BAD:-0} * 100 / PL_TOT ))
  if [ "$PL_PCT" -gt 40 ]; then report "push_delivery" CRIT "Push: 60 dk'da $PL_BAD/$PL_TOT teslim edilemedi (%$PL_PCT)"
  elif [ "$PL_PCT" -gt 20 ]; then report "push_delivery" WARN "Push: 60 dk'da $PL_BAD/$PL_TOT teslim edilemedi (%$PL_PCT)"
  else [ -f "$STATE/push_delivery" ] && report "push_delivery" OK "push teslimi normal (%$PL_PCT basarisiz)"
  fi
fi

# --- 23. Dead-man switch (03.09.2026, A7) ---
# Bu script susarsa sessizlik "saglik" gibi gorunur. /root/monitoring/heartbeat.url dosyasinda
# dis heartbeat adresi (healthchecks.io) varsa her kosuda ping; adres gelmezse e-posta+Telegram
# oradan gelir. Dosya yoksa adim atlanir (kurulum Mustafa'da).
if [ -s "$DIR/heartbeat.url" ]; then
  curl -fsS -m 10 --retry 2 "$(cat "$DIR/heartbeat.url")" >/dev/null 2>&1 || true
fi

# --- 24. Restore tatbikati tazeligi (03.09.2026, C2) ---
# /root/bin/restore-drill.sh ayin 1'i 05:00 kosar; damga 35 gunden eskiyse veya ok=false ise uyar.
RD=/root/backups/offsite/last-restore-drill.json
if [ -f "$RD" ]; then
  RD_DATE=$(python3 -c "import json;print(json.load(open('$RD')).get('date',''))" 2>/dev/null)
  RD_OK=$(python3 -c "import json;print(json.load(open('$RD')).get('ok'))" 2>/dev/null)
  RD_AGE=$(( ( $(date +%s) - $(date -d "${RD_DATE:-1970-01-01}" +%s) ) / 86400 ))
  if [ "$RD_OK" != "True" ]; then report "restore_drill" CRIT "son restore tatbikati BASARISIZ ($RD_DATE) — yedek geri yuklenemiyor olabilir"
  elif [ "$RD_AGE" -gt 35 ]; then report "restore_drill" WARN "restore tatbikati $RD_AGE gundur yapilmadi"
  else [ -f "$STATE/restore_drill" ] && report "restore_drill" OK "tatbikat guncel ($RD_DATE)"
  fi
fi
