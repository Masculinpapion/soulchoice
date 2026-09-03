#!/usr/bin/env bash
# /root/bin/restore-drill.sh — AYLIK OTOMATİK RESTORE TATBİKATI (03.09.2026, kalite teşhisi C2).
# Son yerel dump'ı (03:00 cron) aynı Supabase Postgres imajından geçici bir konteynere restore eder,
# kritik tabloların satır sayılarını canlıyla karşılaştırır, /root/backups/offsite/last-restore-drill.json
# damgasını yazar, Telegram'a sonuç bildirir ve konteyneri siler. Canlı DB'ye DOKUNMAZ.
# Cron: 0 5 1 * *  (ayın 1'i 05:00 UTC). Elle: bash /root/bin/restore-drill.sh
set -u
DUMP=$(ls -t /root/backups/db_*.sql.gz 2>/dev/null | head -1)
IMG=$(docker inspect supabase-db --format '{{.Config.Image}}')
NAME=restore-drill
STAMP=/root/backups/offsite/last-restore-drill.json
ALERT=/root/monitoring/alert.sh
LOG=/root/backups/restore-drill.log
TABLES="users invitations applications matches messages payments subscriptions notifications"
fail() { echo "$(date -Is) FAIL: $1" >> "$LOG"; printf '{"date":"%s","ok":false,"note":"%s"}\n' "$(date +%F)" "$1" > "$STAMP"; $ALERT CRIT "restore tatbikatı BAŞARISIZ: $1 (dump: $(basename "${DUMP:-yok}"))"; docker rm -f $NAME >/dev/null 2>&1; exit 1; }
[ -n "$DUMP" ] || fail "yerel dump bulunamadı"
[ "$(stat -c %s "$DUMP")" -gt 1000000 ] || fail "dump çok küçük ($(stat -c %s "$DUMP") bayt)"
docker rm -f $NAME >/dev/null 2>&1
docker run -d --name $NAME --network none -e POSTGRES_PASSWORD=drill "$IMG" >/dev/null 2>&1 || fail "konteyner başlatılamadı"
for i in $(seq 1 60); do docker exec $NAME pg_isready -U supabase_admin >/dev/null 2>&1 && break; sleep 2; done
docker exec $NAME pg_isready -U supabase_admin >/dev/null 2>&1 || fail "postgres 120 sn'de hazır olmadı"
sleep 5
# Taze "drill" veritabanı: imajın hazır auth/storage şemalarıyla çakışma olmaz. pg_cron yalnız
# postgres db'de kurulabildiği için cron.* tabloları COPY için stub olarak açılır; eksik rol eklenir.
PSQL="docker exec -e PGPASSWORD=drill $NAME psql -U supabase_admin"
$PSQL -d postgres -Atc "create database drill" >/dev/null 2>&1 || fail "drill db oluşturulamadı"
$PSQL -d drill -q -c "do \$\$ begin if not exists (select 1 from pg_roles where rolname='supabase_functions_admin') then create role supabase_functions_admin nologin; end if; end \$\$; create schema if not exists cron; create table if not exists cron.job(jobid bigint, schedule text, command text, nodename text, nodeport int, database text, username text, active boolean, jobname text); create table if not exists cron.job_run_details(jobid bigint, runid bigint, job_pid int, database text, username text, command text, status text, return_message text, start_time timestamptz, end_time timestamptz);" >/dev/null 2>&1
ERRS=$(gunzip -c "$DUMP" | docker exec -i -e PGPASSWORD=drill $NAME psql -U supabase_admin -d drill -q 2>&1 | grep -c "^ERROR" || true)
BAD=""; DETAIL=""
for t in $TABLES; do
  live=$(docker exec supabase-db psql -U postgres -Atc "select count(*) from public.$t" 2>/dev/null); live=${live:-?}
  rest=$(docker exec -e PGPASSWORD=drill $NAME psql -U supabase_admin -d drill -Atc "select count(*) from public.$t" 2>/dev/null); rest=${rest:-?}
  DETAIL="$DETAIL $t=$rest/$live"
  # Dump 03:00'te alınır, gün içinde canlı değişir: para/hesap tabloları sıkı (≤3), sosyal tablolar ±%10,
  # applications/notifications (vitrin simülasyonu sürekli siler/ekler) yalnız bilgi amaçlı.
  if [ "$rest" = "?" ] || [ "$live" = "?" ]; then BAD="$BAD $t(okunamadı)"; continue; fi
  diff=$(( live - rest )); [ $diff -lt 0 ] && diff=$(( -diff ))
  case $t in payments|subscriptions|users) lim=3 ;; applications|notifications) lim=999999 ;; *) lim=$(( live / 10 + 2 )) ;; esac
  [ $diff -le $lim ] || BAD="$BAD $t($rest≠$live)"
done
docker rm -f $NAME >/dev/null 2>&1
if [ -z "$BAD" ]; then
  printf '{"date":"%s","ok":true,"db_rows_match":true,"psql_errors":%s,"dump":"%s","detail":"%s"}\n' "$(date +%F)" "$ERRS" "$(basename "$DUMP")" "$DETAIL" > "$STAMP"
  echo "$(date -Is) OK errs=$ERRS$DETAIL" >> "$LOG"
  $ALERT INFO "✅ restore tatbikatı OK ($(basename "$DUMP"), psql hata $ERRS):$DETAIL"
else
  fail "satır sayıları uyuşmadı:$BAD (psql hata $ERRS)"
fi
