#!/usr/bin/env bash
# /root/monitoring/demo-autoextend.sh — Apple App Review demo daveti bekçisi (18.08.2026)
# Demo hesabın (+70000000001) aktif davetine 36 saatten az kaldıysa expires_at + event_date'i
# +4 gün ileri alır (pending başvurular korunur) ve Telegram'a INFO düşer.
# Emniyet: HARD_STOP tarihinden sonra uzatmaz, WARN atar. Kapatmak: crontab satırını sil.
# Kullanım: demo-autoextend.sh [--dry-run]
set -u
HARD_STOP="2026-10-31"
THRESHOLD_HOURS=36
EXTEND_DAYS=4
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
Q() { docker exec supabase-db psql -U postgres -d postgres -Atc "$1"; }
ALERT=/root/monitoring/alert.sh

ROW=$(Q "select i.id||'|'||to_char(i.expires_at at time zone 'Europe/Moscow','DD.MM HH24:MI')||'|'||round(extract(epoch from (i.expires_at-now()))/3600)
  from public.invitations i join auth.users u on u.id=i.owner_id
  where u.phone like '%70000000001' and i.status='active' order by i.expires_at limit 1;")
if [ -z "$ROW" ]; then
  echo "$(date +%F_%T) demo aktif davet yok"
  [ $DRY -eq 0 ] && $ALERT WARN "🍎 Demo davet bekçisi: +70000000001 hesabında AKTİF davet YOK — Apple sahnesi boş, kontrol et."
  exit 0
fi
ID=${ROW%%|*}; REST=${ROW#*|}; EXP=${REST%%|*}; HOURS=${REST##*|}
# 29.09: sahne bütünlüğü — RuStore moderatörü demo hesabıyla bir başvuranı seçti (onaysız
# eşleşme kuruldu) ve ancak tesadüfen fark edildi. Beklenen: 5 pending / 0 eşleşme.
# Değişince TEK KEZ CRIT (durum dosyası); Apple inceleyicisi de seçmiş olabilir → önce ASC.
SCENE=$(Q "select (select count(*) from public.applications where invitation_id='${ID}' and status='pending')||'/'||(select count(*) from public.matches where invitation_id='${ID}');")
SCENE_STATE=/root/monitoring/state/demo_scene
PREV_SCENE=$(cat "$SCENE_STATE" 2>/dev/null)
if [ -n "$SCENE" ] && [ "$SCENE" != "5/0" ] && [ "$SCENE" != "$PREV_SCENE" ] && [ $DRY -eq 0 ]; then
  $ALERT CRIT "🍎 Demo sahnesi DEĞİŞTİ: White Rabbit pending/eşleşme = $SCENE (beklenen 5/0). Mağaza moderatörü ya da Apple inceleyicisi seçim yapmış olabilir — önce ASC'ye bak, sonra geri al (örnek: /root/backups/demo_selection_rollback_20260929.sql)."
fi
[ $DRY -eq 0 ] && [ -n "$SCENE" ] && echo "$SCENE" > "$SCENE_STATE"
echo "$(date +%F_%T) demo sahnesi pending/eşleşme=$SCENE"
if [ "$HOURS" -ge "$THRESHOLD_HOURS" ]; then
  echo "$(date +%F_%T) demo davet $ID bitiş $EXP MSK, kalan ${HOURS}s >= ${THRESHOLD_HOURS}s -> dokunma"
  exit 0
fi
if [ "$(date +%F)" \> "$HARD_STOP" ]; then
  echo "$(date +%F_%T) HARD_STOP gecti, uzatilmadi"
  [ $DRY -eq 0 ] && $ALERT WARN "🍎 Demo davet ${EXP} MSK'de bitiyor ama emniyet tarihi ${HARD_STOP} geçti — otomatik uzatma DURDU. Apple hâlâ bekliyorsa elle uzat / tarihi güncelle."
  exit 0
fi
if [ $DRY -eq 1 ]; then
  echo "$(date +%F_%T) DRY-RUN: $ID +${EXTEND_DAYS} gun uzatilirdi (su an bitis $EXP MSK, kalan ${HOURS}s)"
  exit 0
fi
NEW=$(Q "update public.invitations set expires_at=expires_at+interval '${EXTEND_DAYS} days', event_date=event_date+interval '${EXTEND_DAYS} days'
  where id='${ID}' and status='active'
  returning to_char(expires_at at time zone 'Europe/Moscow','DD.MM.YYYY HH24:MI')||' / etkinlik '||to_char(event_date at time zone 'Europe/Moscow','DD.MM HH24:MI')||' / pending '||(select count(*) from public.applications a where a.invitation_id=invitations.id and a.status='pending');")
if [ -n "$NEW" ]; then
  echo "$(date +%F_%T) UZATILDI -> $NEW"
  $ALERT INFO "🍎 Demo davet (Apple review) otomatik uzatıldı: yeni bitiş ${NEW} MSK. Apple cevap verince crontab'dan demo-autoextend satırını kaldır."
else
  echo "$(date +%F_%T) UPDATE 0 satir"
  $ALERT WARN "🍎 Demo davet uzatma DENENDİ ama UPDATE 0 satır döndü — elle kontrol et (id ${ID})."
fi
