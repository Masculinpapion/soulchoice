#!/usr/bin/env bash
# /root/bin/billing-cron.sh — host crontab'dan billing-cron tetikleyicisi.
# Crontab satırları (root):
#   25 7 * * *        /root/bin/billing-cron.sh          # günlük tam digest (07:25 UTC = 10:25 MSK)
#   25 0-6,8-23 * * * /root/bin/billing-cron.sh quiet    # saatlik (03.09): aktivite/kırmızı yoksa mail yok
# (flock üst üste koşmayı engeller; log: /var/log/billing-cron.log; fonksiyon idempotent —
#  notified_at / max_daily_attempts / 96 sa pencere kapıları var, saatlik koşu çift çekim yapmaz)
set -u
exec 9>/tmp/billing-cron.lock
flock -n 9 || { echo "$(date -Is) SKIP: onceki kosu bitmedi" >> /var/log/billing-cron.log; exit 0; }

MODE=${1:-full}
BODY='{}'
[ "$MODE" = "quiet" ] && BODY='{"quiet":true}'

KEY=$(grep "^SERVICE_ROLE_KEY=" /root/supabase/docker/.env | cut -d= -f2-)
{
  echo "=== $(date -Is) billing-cron ($MODE) ==="
  curl -sS -m 570 -X POST https://soulchoice.app/functions/v1/billing-cron \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$BODY"
  echo
} >> /var/log/billing-cron.log 2>&1
