#!/usr/bin/env bash
# /root/bin/selection-reminder.sh — saatlik owner secim hatirlatmasi (yolculuk bulgusu #5)
set -u
exec 9>/tmp/selection-reminder.lock
flock -n 9 || exit 0
KEY=$(grep "^SERVICE_ROLE_KEY=" /root/supabase/docker/.env | cut -d= -f2-)
{
  echo "=== $(date -Is) selection-reminder ==="
  curl -sS -m 120 -X POST https://soulchoice.app/functions/v1/selection-reminder \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d '{}'
  echo
} >> /var/log/selection-reminder.log 2>&1
