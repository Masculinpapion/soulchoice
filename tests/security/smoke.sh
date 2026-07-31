#!/usr/bin/env bash
# GÜVENLİK SMOKE TESTİ — 31.07 denetiminde bulunan "girişsiz erişim" sınıfının
# regresyon bekçisi. Anon anahtarla (uygulamadaki public anahtar) canlı sisteme
# vurur; korumalı her yüzey 2xx DIŞI dönmek ZORUNDA. Bir uç 2xx dönerse
# ya koruma düştü (REVOKE/verify_jwt kaybı) ya da bilinçli açıldı — test kırmızı.
# CI: her push + günlük cron (config drift'i yakalar). Salt-okuma + reddedilen
# istekler; canlı veriye dokunmaz.
set -euo pipefail
cd "$(dirname "$0")/../.."

BASE="https://soulchoice.app"
ANON=$(grep -A2 "SUPABASE_ANON_KEY" lib/core/constants/supabase_constants.dart |
  grep -o "eyJ[A-Za-z0-9._-]*")
[ -n "$ANON" ] || { echo "FAIL: anon key okunamadı"; exit 1; }

fails=0
must_deny() { # ad, metod, yol, gövde
  local name="$1" method="$2" path="$3" body="${4:-}"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 20 -X "$method" "$BASE$path" \
    -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
    -H 'Content-Type: application/json' ${body:+-d "$body"}) || code=000
  if [[ "$code" =~ ^2 ]]; then
    echo "❌ $name: $code döndü — KORUMA DÜŞMÜŞ ($method $path)"
    fails=$((fails + 1))
  else
    echo "✅ $name: $code (reddedildi)"
  fi
}

# KANARYA: anon anahtarın canlı olduğunu kanıtla — bu 2xx dönmezse tüm
# "reddedildi"ler anlamsız (bozuk anahtar da her yerde 401 verir = sahte yeşil)
canary=$(curl -s -o /dev/null -w '%{http_code}' -m 20 \
  "$BASE/rest/v1/feature_flags?select=key&limit=1" -H "apikey: $ANON") || canary=000
if [[ "$canary" =~ ^2 ]]; then
  echo "✅ kanarya (feature_flags public read): $canary"
else
  echo "❌ kanarya: $canary — anon anahtar/API sorunlu, sonuçlar geçersiz"
  exit 1
fi

# 31.07 açık #1: ops moderasyon RPC'leri (REVOKE bekçisi) — parametre adları
# GERÇEK imzayla eşleşmeli, yoksa 404 döner ve koruma kaybı görünmez olur
must_deny "ops_search_users anon"  POST /rest/v1/rpc/ops_search_users '{"q":"a"}'
must_deny "ops_ban_user anon"      POST /rest/v1/rpc/ops_ban_user '{"p_user":"00000000-0000-0000-0000-000000000000","p_actor":"smoke","p_note":"test"}'
# 31.07 açık #2/#6: service-key şartlı fonksiyonlar (verify bekçisi)
must_deny "send-notification anon" POST /functions/v1/send-notification '{"user_id":"x","title":"t","body":"b"}'
must_deny "selection-reminder anon" POST /functions/v1/selection-reminder '{}'
must_deny "billing-cron anon"      POST /functions/v1/billing-cron '{}'
must_deny "send-premium-sms anon"  POST /functions/v1/send-premium-sms '{}'
# Kullanıcı JWT'si şartlı fonksiyon (anon key ≠ kullanıcı)
must_deny "create-tochka-payment anon" POST /functions/v1/create-tochka-payment '{}'
must_deny "manage-subscription anon"   POST /functions/v1/manage-subscription '{"action":"status"}'
# 31.07 açık #5: users kolon gizliliği (telefon/e-posta/token sızıntısı)
must_deny "users.phone anon"       GET "/rest/v1/users?select=phone&limit=1"
must_deny "users.fcm_token anon"   GET "/rest/v1/users?select=fcm_token&limit=1"
# 31.07 açık #3: matches'e zorla eşleşme (insert)
must_deny "matches insert anon"    POST /rest/v1/matches '{"invitation_id":"00000000-0000-0000-0000-000000000000","user1_id":"00000000-0000-0000-0000-000000000000","user2_id":"00000000-0000-0000-0000-000000000000"}'
# photoFocus RPC yalnız authenticated (01.08 anon-default-privilege dersi)
must_deny "photo_focus_entries anon" POST /rest/v1/rpc/photo_focus_entries '{}'
# Gizli storage bucket'ı
must_deny "selfies bucket anon"    GET "/storage/v1/object/selfies/x/y.jpg"

if [ "$fails" -gt 0 ]; then
  echo; echo "SONUÇ: $fails yüzeyde koruma düşmüş — ACİL bak."
  exit 1
fi
echo; echo "SONUÇ: tüm korumalı yüzeyler reddediyor ✅"
