#!/usr/bin/env bash
# /root/monitoring/alert.sh — Telegram alarm gönderici
# 19.07.2026: retry (3x) + kalıcı kuyruk + CRIT için SMS fallback eklendi.
# Kullanım: alert.sh <CRIT|WARN|OK|INFO> <mesaj...>
#           alert.sh --flush   → kuyruktaki gönderilememiş alarmları yeniden dener
#                                (checks.sh her koşu başında çağırır; alarm kaybolmaz, en kötü gecikir)
set -u
source /root/monitoring/.env

QUEUE=/root/monitoring/state/alert.queue

send_tg() { # send_tg <text> → 0 başarılı; 4 deneme (6 sn tavan), aralarda 1/2/3 sn
  # 16.09: --http1.1 — Timeweb→Telegram HTTP/2 GET/POST bazen asılı kalıyor (DPI), 15 sn sonra kuyruğa düşüp 15 dk gecikiyordu; h1.1 0,15 sn
  local try
  for try in 1 2 3 4; do  # 16.09: RKN akış düşürmesi ~1/6 denemede; 6 sn tavan × 4 deneme, aralar 1/2/3 sn
    if curl -sS --http1.1 -m 6 "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" --data-urlencode text="$1" >/dev/null 2>&1; then
      return 0
    fi
    [ "$try" -lt 4 ] && sleep "$try"
  done
  return 1
}

# Kuyruk kaydı TEK SATIR: "<epoch>|<base64(mesaj)>" — çok satırlı mesajlar (günlük
# özet gibi) satır satır bölünüp ayrı mesajlar olarak gitmesin (31.07 bug'ı).
if [ "${1:-}" = "--flush" ]; then
  [ -s "$QUEUE" ] || exit 0
  TMPQ=$(mktemp)
  mv "$QUEUE" "$TMPQ"
  while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)\|([A-Za-z0-9+/=]+)$ ]]; then
      TS="${BASH_REMATCH[1]}"
      TEXT=$(printf '%s' "${BASH_REMATCH[2]}" | base64 -d 2>/dev/null) || TEXT=""
      [ -z "$TEXT" ] && continue
      FULL="${TEXT}
⏳ gecikmeli iletildi (üretim: $(TZ=Europe/Moscow date -d "@${TS}" '+%H:%M') MSK)"
      send_tg "$FULL" || echo "$line" >> "$QUEUE"
    else
      # eski düz-metin kuyruk kaydı (geriye uyum)
      send_tg "$line" || echo "$line" >> "$QUEUE"
    fi
  done < "$TMPQ"
  rm -f "$TMPQ"
  exit 0
fi

LEVEL="${1:-INFO}"; shift || true
MSG="$*"
case "$LEVEL" in
  CRIT) PREFIX="🔴 KRİTİK" ;;
  WARN) PREFIX="🟡 UYARI" ;;
  OK)   PREFIX="✅ OK" ;;
  *)    PREFIX="ℹ️" ;;
esac
# "[soulchoice]" etiketi kaldırıldı (31.07, Mustafa: görsel sadelik — kanal zaten tek)
TEXT="${PREFIX} · ${MSG}"

if ! send_tg "$TEXT"; then
  echo "$(date +%s)|$(printf '%s' "$TEXT" | base64 -w0)" >> "$QUEUE"
  # Telegram 3 denemede de ulaşılamadı ve seviye CRIT: SMS fallback (gerçek para → sadece CRIT).
  # ALERT_SMS_TO /root/monitoring/.env'de tanımlı değilse atlanır.
  if [ "$LEVEL" = "CRIT" ] && [ -n "${ALERT_SMS_TO:-}" ]; then
    SMSKEY=$(grep "^SMS_RU_API_KEY=" /root/supabase/docker/.env | cut -d= -f2-)
    if [ -n "$SMSKEY" ]; then
      {
        echo "$(date -Is) CRIT SMS fallback → ${ALERT_SMS_TO}"
        curl -sS -m 15 "https://sms.ru/sms/send" \
          -d api_id="$SMSKEY" --data-urlencode to="$ALERT_SMS_TO" \
          --data-urlencode msg="SoulChoice KRITIK: ${MSG:0:120} (Telegram ulasilamadi, detay kuyrukta)" -d json=1
        echo
      } >> /root/monitoring/state/sms-fallback.log 2>&1
    fi
  fi
fi
