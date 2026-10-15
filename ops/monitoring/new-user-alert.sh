#!/usr/bin/env bash
# /root/monitoring/new-user-alert.sh — yeni GERCEK kullanici aninda Telegram bildirimi
# (28.08.2026, Mustafa karari: "organik kullanici gelince aninda goreyim")
# Cron: */5. Durum dosyasi: en son bildirilen kaydin created_at'i.
set -u
ST=/root/monitoring/state/last_user_notified
mkdir -p /root/monitoring/state
if [ ! -f "$ST" ]; then
  docker exec supabase-db psql -U postgres -t -A -c \
    "select coalesce(max(created_at),now())::text from users where not is_test_user" > "$ST" 2>/dev/null
fi
LAST=$(cat "$ST")
ROWS=$(docker exec supabase-db psql -U postgres -t -A -F'|' -c \
 "select created_at::text,
         to_char(created_at at time zone 'Europe/Moscow','DD.MM HH24:MI'),
         coalesce(name,'(isimsiz)'), coalesce(age::text,'?'),
         coalesce((select c.name from cities c where c.id=u.city_id),'?'),
         gender, selfie_status,
         coalesce(install_source,'?'), coalesce(app_build::text,'?')
  from users u
  where not is_test_user and not is_deleted and created_at > '$LAST'
  order by created_at" 2>/dev/null)
[ -z "$ROWS" ] && exit 0
NEWLAST="$LAST"
while IFS='|' read -r TS DISP NAME AGE CITY GEN SST SRC BLD; do
  [ -z "$TS" ] && continue
  ICON="👤"; [ "$GEN" = "female" ] && ICON="👩"; [ "$GEN" = "male" ] && ICON="👨"
  # 26.09 (Play yayını): kaynak = users.install_source (istemci yazar; eski build'lerde '?')
  case "$SRC" in
    play) SRCTXT="Google Play" ;; rustore) SRCTXT="RuStore" ;; apk) SRCTXT="APK (site)" ;;
    appstore) SRCTXT="App Store" ;; testflight) SRCTXT="TestFlight" ;; web) SRCTXT="Web" ;;
    *) SRCTXT="? ($SRC)" ;;
  esac
  /root/monitoring/alert.sh INFO "🎉 YENI KULLANICI $ICON $NAME, $AGE — $CITY
Kayit: $DISP MSK · Selfie: $SST
Kaynak: $SRCTXT · build $BLD"
  NEWLAST="$TS"
done <<< "$ROWS"
echo "$NEWLAST" > "$ST"
