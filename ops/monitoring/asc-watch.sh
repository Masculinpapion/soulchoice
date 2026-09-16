#!/bin/bash
# /root/monitoring/asc-watch.sh — ASC bekçisi, sunucu tarafı (17.09.2026).
# stdin: asc-watch.py'nin JSON özeti (GitHub Actions ssh ile gönderir).
# Önceki özetle karşılaştırır, alert.sh ile Telegram'a yazar:
#   - durum satırı değişti            → ℹ️ INFO  (🍎 ASC: eski → yeni)
#   - REJECTED / UNRESOLVED_ISSUES /
#     DEVELOPER_ACTION_NEEDED          → 🔴 CRIT (report() günde 1 hatırlatır)
#   - WAITING_FOR_REVIEW/IN_REVIEW
#     ≥ 72 saat                        → 🔴 CRIT günlük «ASC'ye bak / Contact Us»
# Sebep: 12.09 beta 273 REJECTED (2.1 soru) 5 gün görülmedi, 275 kuyrukta bekledi.
set -u
DIR=/root/monitoring; STATE=$DIR/state; ALERT=$DIR/alert.sh
mkdir -p "$STATE"
IN=$(cat)
[ -z "$IN" ] && { echo "asc-watch: boş girdi"; exit 1; }
echo "$IN" > "$STATE/asc_last.json"

SUMMARY=$(IN_JSON="$IN" python3 - <<'PY'
import os, json, datetime
d = json.loads(os.environ["IN_JSON"])
parts, bad, oldest_wait_h = [], [], 0
now = datetime.datetime.utcnow()
for v in d.get("versions", []):
    parts.append("v%s=%s" % (v.get("v"), v.get("state")))
    if v.get("state") in ("REJECTED", "DEVELOPER_REJECTED", "METADATA_REJECTED", "INVALID_BINARY"):
        bad.append("sürüm %s %s" % (v.get("v"), v.get("state")))
for s in d.get("submissions", []):
    parts.append("sub%s=%s" % (s.get("id"), s.get("state")))
    if s.get("state") == "UNRESOLVED_ISSUES":
        bad.append("gönderim %s UNRESOLVED_ISSUES" % s.get("id"))
    if s.get("state") in ("WAITING_FOR_REVIEW", "IN_REVIEW") and s.get("submitted"):
        t = datetime.datetime.strptime(s["submitted"][:19], "%Y-%m-%dT%H:%M:%S")
        oldest_wait_h = max(oldest_wait_h, int((now - t).total_seconds() // 3600))
for b in d.get("betas", []):
    if b.get("beta_state") and b.get("beta_state") != "APPROVED":   # APPROVED = gürültü (her CI build'i)
        parts.append("beta%s=%s" % (b.get("build"), b.get("beta_state")))
        if b.get("beta_state") == "REJECTED":
            bad.append("beta %s REJECTED (ASC thread'inde mesaj olabilir)" % b.get("build"))
print(" | ".join(parts))
print(" ; ".join(bad))
print(oldest_wait_h)
PY
)
LINE=$(printf '%s\n' "$SUMMARY" | sed -n 1p)
BAD=$(printf '%s\n' "$SUMMARY" | sed -n 2p)
WAIT_H=$(printf '%s\n' "$SUMMARY" | sed -n 3p)
echo "$(date -Is) asc-watch: $LINE ${BAD:+| BAD: $BAD} | wait_h=$WAIT_H"

# asc_last.json'a bekleme süresini de yaz (nöbet rutini bu dosyayı okur; 17.09 «4 aydır bekliyor» yorum hatası)
IN_JSON="$IN" WAIT_H="$WAIT_H" python3 - > "$STATE/asc_last.json" <<'PY'
import os, json, sys
d = json.loads(os.environ["IN_JSON"])
d["wait_h"] = int(os.environ["WAIT_H"] or 0)
d["wait_days"] = d["wait_h"] // 24
d["note"] = "wait_h/wait_days = en eski açık gönderimin (submitted) bekleme süresi; başka hiçbir tarih alanı bekleme süresi DEĞİLDİR"
json.dump(d, sys.stdout, ensure_ascii=False)
PY

# report() kopyası (checks.sh ile aynı semantik: değişimde bildir, CRIT günde 1 hatırlat)
report() {
  local name=$1 status=$2 msg=$3
  local f="$STATE/$name" prev="OK"   # set -u: $name aynı local satırında henüz yok (17.09 ilk koşu dersi)
  [ -f "$f" ] && prev=$(cat "$f")
  if [ "$status" != "$prev" ]; then
    if [ "$status" = "OK" ]; then $ALERT OK "$name düzeldi: $msg"; rm -f "$f" "$STATE/$name.reminded"
    else $ALERT "$status" "$name: $msg"; echo "$status" > "$f"; fi
  elif [ "$status" = "CRIT" ]; then
    local stamp="$STATE/$name.reminded"
    if [ ! -f "$stamp" ] || [ "$(date +%F)" != "$(cat "$stamp")" ]; then
      $ALERT CRIT "$name SÜRÜYOR: $msg"; date +%F > "$stamp"
    fi
  fi
}

# 1) Durum satırı değişti mi → INFO
PREV_LINE=$(cat "$STATE/asc_line" 2>/dev/null || true)
if [ "$LINE" != "$PREV_LINE" ]; then
  if [ -n "$PREV_LINE" ]; then
    $ALERT INFO "🍎 ASC durumu değişti: $LINE (önceki: $PREV_LINE) — appstoreconnect.apple.com/apps/6768422521/distribution/reviewsubmissions"
  else
    $ALERT INFO "🍎 ASC bekçisi kuruldu, ilk durum: $LINE"
  fi
  echo "$LINE" > "$STATE/asc_line"
fi

# 2) Red / çözülmemiş sorun → CRIT (günlük hatırlatma)
if [ -n "$BAD" ]; then report asc_issue CRIT "🍎 Apple aksiyon istiyor: $BAD → ASC App Review sayfasını AÇ, mesajı aynı gün cevapla"
else report asc_issue OK "Apple'da açık sorun yok"; fi

# 3) 72 saatten uzun bekleme → CRIT (günlük hatırlatma)
if [ "${WAIT_H:-0}" -ge 72 ]; then report asc_wait CRIT "🍎 inceleme $((WAIT_H/24)) gündür bekliyor ($LINE) → ASC'de Apple mesajı var mı bak (reviewsubmissions + son TestFlight thread); Apple İTTİRİLMEZ, yalnız soru gelirse aynı gün cevap"
else report asc_wait OK "bekleme normal (${WAIT_H:-0} saat)"; fi
