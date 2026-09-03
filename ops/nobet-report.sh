#!/usr/bin/env bash
# /root/bin/nobet-report.sh — bulut Nöbet rutini için SALT-OKUMA rapor (03.09.2026).
# Cron: */5 * * * *  → /var/www/soulchoice/nobet/<token>/report.json (nginx /nobet/ ile yayınlanır).
# Rutin sunucuya SSH YAPMAZ; yalnız bu JSON'u okur. Kişisel veri yok; telefon numaraları maskelenir.
set -u
TOKEN=$(cat /root/monitoring/nobet_report.token)
OUT_DIR=/var/www/soulchoice/nobet/$TOKEN; mkdir -p "$OUT_DIR"
P() { docker exec supabase-db psql -U postgres -Atc "$1" 2>/dev/null; }
mask() { sed -E 's/7[0-9]{6}([0-9]{4})/7******\1/g'; }
j() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
CONT=$(docker ps -a --format '{{.Names}}|{{.Status}}' | sort | python3 -c 'import sys,json; print(json.dumps(dict(l.strip().split("|",1) for l in sys.stdin if "|" in l)))')
STATE=$(cd /root/monitoring/state 2>/dev/null && for f in *; do [ -f "$f" ] && [ "$(wc -l < "$f")" -le 1 ] && case "$f" in *.reminded|*.log) ;; *) printf '%s=%s\n' "$f" "$(head -c 120 "$f" | tr -d '\n')";; esac; done | mask | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
LOGT=$(tail -15 /root/monitoring/checks.log 2>/dev/null | cut -c1-200 | mask | j)
K5=$(docker logs supabase-kong --since 60m 2>&1 | grep -cE '" 5[0-9]{2} '); K5=${K5:-0}
EDGE=$(docker logs supabase-edge-functions --since 60m 2>&1 | grep -iE 'ERROR|FAIL|RPC_FAILED|OTP_CAP|STORE_CAP' | tail -15 | cut -c1-200 | mask | j)
ROW=$(P "select json_build_object(
 'signups_60m',(select count(*) from auth.users where created_at > now()-interval '60 minutes'),
 'signups_24h',(select count(*) from auth.users where created_at > now()-interval '24 hours'),
 'otp_sent_60m',(select count(*) from otp_send_log where created_at > now()-interval '60 minutes' and result='sent'),
 'otp_verified_60m',(select count(*) from otp_send_log where created_at > now()-interval '60 minutes' and result='verified'),
 'otp_fail_60m',(select count(*) from otp_send_log where created_at > now()-interval '60 minutes' and result like 'fail:%'),
 'otp_sent_24h',(select count(*) from otp_send_log where created_at > now()-interval '24 hours' and result='sent'),
 'otp_verified_24h',(select count(*) from otp_send_log where created_at > now()-interval '24 hours' and result='verified'),
 'payments_60m',(select count(*) from payments where paid_at > now()-interval '60 minutes' and status='paid'),
 'payments_24h',(select count(*) from payments where paid_at > now()-interval '24 hours' and status='paid'),
 'client_errors_60m',(select count(*) from client_errors where created_at > now()-interval '60 minutes' and platform<>'test'),
 'client_errors_24h',(select count(*) from client_errors where created_at > now()-interval '24 hours' and platform<>'test'),
 'client_errors_top',(select coalesce(json_agg(t),'[]'::json) from (select left(error,120) as e, count(*) as n from client_errors where created_at > now()-interval '24 hours' and platform<>'test' group by 1 order by 2 desc limit 3) t),
 'push_total_60m',(select count(*) from push_log where sent_at > now()-interval '60 minutes' and status is not null),
 'push_fail_60m',(select count(*) from push_log where sent_at > now()-interval '60 minutes' and status in ('unregistered','fcm_fail','rustore_fail','no_token')),
 'db_connections',(select count(*) from pg_stat_activity),
 'demo_invitation',(select json_build_object('status',status,'expires_at',expires_at) from invitations where id='33db9e96-7624-4803-881b-384890b6ee90'),
 'billing_heartbeat',(select json_build_object('last_run_at',last_run_at,'status',last_status) from cron_heartbeat where job='billing-cron')
)")
DISK=$(df --output=pcent / | tail -1 | tr -dc '0-9'); MEM=$(free -m | awk 'NR==2{printf "%d/%d", $3, $2}'); LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
SITE=$(curl -s -o /dev/null -m 10 -w '%{http_code}' https://soulchoice.app/); REST=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "https://soulchoice.app/rest/v1/cities?select=id&limit=1")
DM=$(curl -s -m 10 https://hb.ahmtransfer.com/status || echo '{}')
SMS=$(curl -s -m 10 "https://sms.ru/my/balance?api_id=$(grep -o '^SMS_RU_API_KEY=.*' /root/supabase/docker/.env | cut -d= -f2)&json=1" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("balance","?"))' 2>/dev/null || echo '?')
python3 - "$CONT" "$STATE" "$LOGT" "$K5" "$EDGE" "$ROW" "$DISK" "$MEM" "$LOAD" "$SITE" "$REST" "$DM" "$SMS" > "$OUT_DIR/report.json.tmp" <<'PY'
import sys,json,datetime
a=sys.argv[1:]
rep={"generated_at_utc":datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
 "containers":json.loads(a[0]),"alarm_state_files":json.loads(a[1]),"checks_log_tail":json.loads(a[2]),
 "kong_5xx_60m":int(a[3] or 0),"edge_errors_60m_tail":json.loads(a[4]),"db":json.loads(a[5] or '{}'),
 "disk_pct":int(a[6] or 0),"mem_used_total_mb":a[7],"loadavg":a[8],"site_http":a[9],"rest_http":a[10],
 "deadman":json.loads(a[11] or '{}'),"sms_ru_balance":a[12]}
print(json.dumps(rep,ensure_ascii=False,indent=1))
PY
mv "$OUT_DIR/report.json.tmp" "$OUT_DIR/report.json"; chmod 644 "$OUT_DIR/report.json"
