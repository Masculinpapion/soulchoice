#!/usr/bin/env bash
# /root/monitoring/daily-digest.sh — günlük büyüme özeti (29.07.2026, Mustafa)
# Her sabah 09:00 MSK Telegram'a tek mesaj; panele girmeden nabız tutulur.
set -u
Q() { docker exec supabase-db psql -U postgres -t -A -c "$1" 2>/dev/null | head -1; }

NEW=$(Q "select count(*) from users where created_at > now()-interval '24 hours' and not is_test_user")
TOTAL=$(Q "select count(*) from users where not is_test_user and not is_deleted")
SELFOK=$(Q "select count(*) from audit_log where action like '%approve_selfie%' and ts > now()-interval '24 hours'")
APPS=$(Q "select count(*) from applications a join users u on u.id=a.applicant_id where a.created_at > now()-interval '24 hours' and not u.is_test_user")
MATCH=$(Q "select count(*) from matches m where m.created_at > now()-interval '24 hours' and (exists(select 1 from users u where u.id=m.user1_id and not u.is_test_user) or exists(select 1 from users u where u.id=m.user2_id and not u.is_test_user))")
PAY=$(Q "select coalesce(sum(amount),0) from payments where status='paid' and paid_at > now()-interval '24 hours'")
PEND=$(Q "select count(*) from v_pending_selfies")
REP=$(Q "select count(*) from v_open_reports")
CITY=$(Q "select count(*) from city_requests where created_at > now()-interval '24 hours'")

/root/monitoring/alert.sh INFO "📊 Günlük özet
• Yeni kayıt: ${NEW:-?} (toplam gerçek: ${TOTAL:-?})
• Selfie onayı: ${SELFOK:-?} · Bekleyen selfie: ${PEND:-?}
• Başvuru: ${APPS:-?} · Eşleşme: ${MATCH:-?}
• Ödeme: ${PAY:-0}₽ · Açık şikayet: ${REP:-?} · Şehir talebi: ${CITY:-?}"

# --- Sabah Devriyesi eki (12.08.2026, Mustafa karari) ---
CERR=$(Q "select count(*) from client_errors where created_at > now()-interval '24 hours' and platform <> 'test'")
CETOP=$(Q "select left(error,90)||' ('||count(*)||'x)' from client_errors where created_at > now()-interval '24 hours' and platform <> 'test' group by left(error,90) order by count(*) desc limit 1")
SMSFAIL=$(docker logs supabase-edge-functions --since 24h 2>&1 | grep -c "send-call-otp SMS_FAILED")
OTPOK=$(docker logs supabase-kong --since 24h 2>&1 | grep "send-call-otp" | grep -c '" 200 ')
QLEN=$(cat /root/monitoring/state/alert.queue 2>/dev/null | wc -l)
RSVER=$(curl -s -m 10 "https://www.rustore.ru/catalog/app/com.soulchoice.soulchoice" | grep -oE '1\.0\.0\([0-9]+\)' | head -1)
EKHATA=""
if [ "${CERR:-0}" != "0" ]; then EKHATA=" - en sik: ${CETOP:-?}"; fi
/root/monitoring/alert.sh INFO "🐝 Sabah Devriyesi
- Istemci hatasi (24s): ${CERR:-0}${EKHATA}
- OTP: ${OTPOK:-?} basarili gonderim, ${SMSFAIL:-0} SMS reddi
- RuStore gorunen surum: ${RSVER:-okunamadi}
- Alarm kuyrugu: ${QLEN:-0} bekleyen
- Apple maili + ASC + Play konsolu -> oturumda Fable bakar"

# --- Yeni kullanici adim haritasi (04.09.2026, Mustafa: kisi bazinda nerede durdu) ---
NEWU=$(docker exec supabase-db psql -U postgres -t -A -c "select string_agg(line, E'\n' order by created_at desc) from (
  select u.created_at, coalesce(u.name,'?')||' ('||to_char(u.created_at at time zone 'Europe/Moscow','DD.MM HH24:MI')||') '
    ||case when exists(select 1 from user_photos p where p.user_id=u.id and not p.is_selfie) then 'foto✓' else 'foto✗' end||' '
    ||case u.selfie_status when 'approved' then 'selfie✓' when 'pending' then 'selfie⏳' when 'rejected' then 'selfie✗('||coalesce(u.selfie_rejected_reason,'')||')' else 'selfie-' end||' '
    ||case when exists(select 1 from invitations i where i.owner_id=u.id) then 'ilan✓' when exists(select 1 from applications a where a.applicant_id=u.id) then 'basvuru✓' else 'ilan/basvuru✗' end
    ||case when exists(select 1 from city_requests c where c.user_id=u.id) then ' sehir-talebi✓' else '' end
    ||case when u.last_seen_at > u.created_at + interval '30 minutes' then ' geri-geldi✓' else '' end as line
  from users u where not u.is_test_user and not u.is_deleted and u.created_at > now()-interval '24 hours') s" 2>/dev/null)
ORPH=$(Q "select count(*) from auth.users a where a.created_at > now()-interval '24 hours' and not exists (select 1 from users u where u.id=a.id)")
if [ -n "$NEWU" ] || [ "${ORPH:-0}" != "0" ]; then
  /root/monitoring/alert.sh INFO "🧭 Son 24 saat yeni kullanicilar — adim haritasi
${NEWU:--}
OTP gecip profili bitirmeyen: ${ORPH:-0}"
fi

# --- Kayit Hunisi (28.08.2026, Mustafa karari: adim adim dusus takibi) ---
F_REG=$(Q "select count(*) from users where not is_test_user and not is_deleted and created_at > now()-interval '7 days'")
F_PHOTO=$(Q "select count(*) from users u where not is_test_user and not is_deleted and created_at > now()-interval '7 days' and exists(select 1 from user_photos p where p.user_id=u.id and not p.is_selfie)")
F_SELFIE=$(Q "select count(*) from users where not is_test_user and not is_deleted and created_at > now()-interval '7 days' and selfie_status <> 'none'")
F_APPR=$(Q "select count(*) from users where not is_test_user and not is_deleted and created_at > now()-interval '7 days' and selfie_status = 'approved'")
F_APPLY=$(Q "select count(*) from users u where not is_test_user and not is_deleted and created_at > now()-interval '7 days' and (exists(select 1 from applications a where a.applicant_id=u.id) or exists(select 1 from invitations i where i.owner_id=u.id))")
STUCK=$(Q "select count(*) from users where not is_test_user and not is_deleted and selfie_status='none' and created_at < now()-interval '24 hours'")
STUCKNAMES=$(Q "select coalesce(string_agg(name||' ('||to_char(created_at at time zone 'Europe/Moscow','DD.MM')||')', ', ' order by created_at desc),'-') from (select name, created_at from users where not is_test_user and not is_deleted and selfie_status='none' and created_at < now()-interval '24 hours' order by created_at desc limit 5) t")
/root/monitoring/alert.sh INFO "🪜 Kayit hunisi (son 7 gun kohortu)
kayit ${F_REG:-?} -> foto ${F_PHOTO:-?} -> selfie ${F_SELFIE:-?} -> onay ${F_APPR:-?} -> basvuru/ilan ${F_APPLY:-?}
Selfie'de takili (24s+, toplam): ${STUCK:-?} - son: ${STUCKNAMES:-?}"

# RuStore tek-kanal sagligi (29.08): katalog erisilebilir mi + GMS'siz kitle olcumu
RS_HTTP=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 https://www.rustore.ru/catalog/app/com.soulchoice.soulchoice || echo ERR)
NOGMS=$(Q "select count(*) from users where not is_test_user and not is_deleted and fcm_token is null and rustore_token is not null")
OLDBUILD=$(Q "select coalesce(string_agg(app_build||':'||c,' '),'-') from (select app_build, count(*) c from users where not is_test_user and not is_deleted and app_build is not null group by app_build order by app_build) t")
/root/monitoring/alert.sh INFO "🏪 RuStore: katalog HTTP ${RS_HTTP:-?} | GMS'siz kullanici: ${NOGMS:-?} | surum dagilimi: ${OLDBUILD:-?}"
