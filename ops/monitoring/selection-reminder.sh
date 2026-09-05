#!/usr/bin/env bash
# /root/bin/selection-reminder.sh — saatlik owner secim hatirlatmasi (yolculuk bulgusu #5)
# 05.09: cron_heartbeat damgasi yazar (checks.sh §30: damga 130 dk'dan eski veya error ise WARN).
set -u
exec 9>/tmp/selection-reminder.lock
flock -n 9 || exit 0
KEY=$(grep "^SERVICE_ROLE_KEY=" /root/supabase/docker/.env | cut -d= -f2-)
hb() { # hb <status> <detail-json>
  docker exec supabase-db psql -U postgres -d postgres -Atq -c "insert into cron_heartbeat (job,last_run_at,last_status,detail) values ('selection-reminder',now(),'$1','$2'::jsonb) on conflict (job) do update set last_run_at=now(), last_status=excluded.last_status, detail=excluded.detail" >/dev/null 2>&1 || true
}
{
  echo "=== $(date -Is) selection-reminder ==="
  CODE=$(curl -sS -m 120 -o /tmp/selection-reminder.out -w '%{http_code}' -X POST https://soulchoice.app/functions/v1/selection-reminder \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d '{}' || echo "curl_fail")
  cat /tmp/selection-reminder.out 2>/dev/null; echo
  if [ "$CODE" = "200" ]; then hb ok '{"http":200}'; else hb error "{\"http\":\"$CODE\"}"; fi
} >> /var/log/selection-reminder.log 2>&1
