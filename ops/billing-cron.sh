#!/usr/bin/env bash
# /root/bin/billing-cron.sh — host crontab'dan günlük billing-cron tetikleyicisi.
# Crontab satırı (root):  25 7 * * * /root/bin/billing-cron.sh
# (07:25 UTC = 10:25 MSK; flock üst üste koşmayı engeller; log: /var/log/billing-cron.log)
set -u
exec 9>/tmp/billing-cron.lock
flock -n 9 || { echo "$(date -Is) SKIP: onceki kosu bitmedi" >> /var/log/billing-cron.log; exit 0; }

KEY=$(grep "^SERVICE_ROLE_KEY=" /root/supabase/docker/.env | cut -d= -f2-)
{
  echo "=== $(date -Is) billing-cron ==="
  curl -sS -m 570 -X POST https://soulchoice.app/functions/v1/billing-cron \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d '{}'
  echo
} >> /var/log/billing-cron.log 2>&1
