#!/usr/bin/env bash
# /root/bin/profile-nudge.sh — saatlik (host crontab: 50 * * * *).
# Kayıttan ≥24 saat geçmiş, hiç profil fotoğrafı olmayan GERÇEK kullanıcıya
# TEK "profilini tamamla" push'u + in-app bildirim (Mustafa kararı 02.09.2026;
# yolculuk bulgusu: Гоша 28.08 / Александр 01.09 fotoğraf ekranında pes etti,
# uygulama onları bir daha çağırmadı).
# Dedupe: notifications.type='profile_incomplete' satırı varsa bir daha gitmez.
# Gönderim yalnız 10:00–21:59 MSK (gece push yok). DRY=1 → yalnız aday listesi.
# Push metni alıcının locale'ine göre burada seçilir (send-notification'da
# şablon yok; istemci title/body'yi aynen gösterir). Repo kopyası: ops/profile-nudge.sh
# 05.09: cron_heartbeat damgasi yazar (pencere disi = skip_window; checks.sh §30 130 dk'dan eski damgada WARN).
set -u
exec 9>/tmp/profile-nudge.lock
flock -n 9 || exit 0
DRY="${DRY:-0}"
H=$(TZ=Europe/Moscow date +%H); H=$((10#$H))
hb() { # hb <status> <detail-json>
  docker exec supabase-db psql -U postgres -d postgres -Atq -c "insert into cron_heartbeat (job,last_run_at,last_status,detail) values ('profile-nudge',now(),'$1','$2'::jsonb) on conflict (job) do update set last_run_at=now(), last_status=excluded.last_status, detail=excluded.detail" >/dev/null 2>&1 || true
}
if [ "$DRY" != "1" ] && { [ "$H" -lt 10 ] || [ "$H" -gt 21 ]; }; then hb skip_window "{\"hour_msk\":$H}"; exit 0; fi
KEY=$(grep "^SERVICE_ROLE_KEY=" /root/supabase/docker/.env | cut -d= -f2-)
SQL="select u.id, coalesce(u.locale,'ru') from users u
 where coalesce(u.is_test_user,false)=false and u.is_deleted=false and u.banned=false and u.suspended_at is null
   and u.created_at <= now()-interval '24 hours' and u.created_at > now()-interval '30 days'
   and (u.fcm_token is not null or u.rustore_token is not null)
   and not exists (select 1 from user_photos p where p.user_id=u.id and p.is_selfie=false)
   and not exists (select 1 from notifications n where n.user_id=u.id and n.type='profile_incomplete')
 order by u.created_at limit 50"
{
  echo "=== $(date -Is) profile-nudge DRY=$DRY ==="
  docker exec supabase-db psql -U postgres -d postgres -At -F"|" -c "$SQL" | while IFS="|" read -r U LOC; do
    case "$LOC" in
      en) T="Your profile is almost ready 📸"; B="Add your photos to start applying to invitations.";;
      tr) T="Profilin neredeyse hazır 📸"; B="Fotoğraflarını ekle, davetlere başvurmaya başla.";;
      *)  T="Профиль почти готов 📸"; B="Добавь фото — и можно откликаться на приглашения.";;
    esac
    echo "candidate user=$U locale=$LOC"
    [ "$DRY" = "1" ] && continue
    # Önce in-app kayıt (dedupe anahtarı) — insert düşerse push da atlanır
    docker exec supabase-db psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 \
      -c "insert into notifications (user_id,type,title,body,payload) values ('$U','profile_incomplete',\$q\$$T\$q\$,\$q\$$B\$q\$,'{}'::jsonb)" \
      || { echo "insert failed user=$U — push atlandı"; continue; }
    curl -sS -m 30 -X POST https://soulchoice.app/functions/v1/send-notification \
      -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d "{\"user_id\":\"$U\",\"title\":\"$T\",\"body\":\"$B\",\"data\":{\"type\":\"profile_incomplete\"}}"
    echo
  done
} >> /var/log/profile-nudge.log 2>&1
hb ok "{\"dry\":$DRY}"
