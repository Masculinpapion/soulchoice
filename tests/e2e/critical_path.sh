#!/usr/bin/env bash
# tests/e2e/critical_path.sh — KRİTİK YOL E2E (04.09.2026, kalite teşhisi Tier-2 #8).
# CANLI sisteme GERÇEK yazma yapar (iki tahsis edilemeyen test numarasıyla, is_test_user=true):
#   OTP gönder/doğrula (A,B) → kayıt (users upsert) → selfie onayı (servis) → A davet oluşturur →
#   B başvurur → A seçer (match_and_select) → A ve B mesaj yazar → DB doğrulamaları → temizlik.
# 23.08 vakası (31.07'den beri 23 gün kırık kayıt) bu testle aynı gece yakalanırdı.
# Gereksinim: ssh anahtarı (SSH_KEY env veya ~/.ssh/timeweb_prod) — selfie onayı ve temizlik servis
# tarafında psql ile yapılır; geri kalan her şey istemcinin yaptığı gibi PostgREST/edge üzerinden.
set -u
if [ "${E2E_LOCAL:-0}" = "1" ]; then
  # 04.09 akşam (Mustafa): betik SUNUCUNUN İÇİNDE koşar. GitHub runner → Timeweb yolunda paketler nginx'e
  # gelmeden sessizce düşüyordu (4 deneme × 28 sn, iz yok) → yanlış CRIT. Kong'a 127.0.0.1:8000'den gidilir
  # (nginx/DDoS-Guard devre dışı, uygulama yolu Kong'dan itibaren aynı), psql doğrudan docker exec.
  BASE="http://127.0.0.1:8000"
  ANON=$(cat /root/monitoring/anon.key 2>/dev/null)
  [ -n "$ANON" ] || { echo "anon key bulunamadı (/root/monitoring/anon.key)"; exit 2; }
  SSH=""
else
  BASE="https://soulchoice.app"
  ANON=$(grep -A2 "SUPABASE_ANON_KEY" "$(dirname "$0")/../../lib/core/constants/supabase_constants.dart" | grep -o "defaultValue: '[^']*'" | cut -d"'" -f2)
  [ -n "$ANON" ] || { echo "anon key bulunamadı"; exit 2; }
  SSH_KEY=${SSH_KEY:-$HOME/.ssh/timeweb_prod}
  SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=15 root@89.169.1.127"
fi
PA="+70000000008"; PB="+70000000009"
MOSCOW="3f08d6f3-c1c1-4315-996f-4b5232441b44"
FAILS=0
ok()   { echo "✅ $1"; }
fail() { echo "❌ $1"; FAILS=$((FAILS+1)); }
json() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)" 2>/dev/null; }
psql() {
  if [ -z "$SSH" ]; then docker exec supabase-db psql -U postgres -Atc "$1"
  else $SSH "docker exec supabase-db psql -U postgres -Atc \"$1\""; fi
}

# ---------- 0) Temizlik (önceki koşu artıkları) ----------
cleanup() {
  psql "
    delete from public.messages where match_id in (select id from public.matches where user1_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009')) or user2_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009')));
    delete from public.matches where user1_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009')) or user2_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009'));
    delete from public.applications where applicant_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009'));
    delete from public.invitations where owner_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009'));
    delete from public.notifications where user_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009'));
    delete from public.push_log where user_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009'));
    update public.users set free_applications_used = 0 where phone in ('+70000000008','+70000000009','70000000008','70000000009');
    delete from public.city_requests where user_id in (select id from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009'));
    delete from public.city_requests where city_text like 'E2E-%';
    -- 04.09: users satırları da silinir → «kayıt» adımı gerçek yeni kullanıcı gibi INSERT olur (auth satırı kalır, OTP bypass yeniden bulur)
    delete from public.users where phone in ('+70000000008','+70000000009','70000000008','70000000009');
  " >/dev/null 2>&1
}
cleanup

# ---------- 1) OTP → oturum ----------
login() { # login <phone> → token|uid
  local r; r=$(curl -s -m 25 -X POST "$BASE/functions/v1/send-call-otp" -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" -d "{\"phone\":\"$1\",\"channel\":\"sms\"}")
  echo "$r" | grep -q '"success":true' || { echo "send-call-otp $1 → $r" >&2; return 1; }
  r=$(curl -s -m 25 -X POST "$BASE/functions/v1/verify-call-otp" -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" -d "{\"phone\":\"$1\",\"code\":\"1234\"}")
  local tok uid; tok=$(echo "$r" | json "d['access_token']"); uid=$(echo "$r" | json "d['user']['id']")
  [ -n "$tok" ] && [ -n "$uid" ] || { echo "verify-call-otp $1 → ${r:0:200}" >&2; return 1; }
  echo "$tok|$uid"
}
A=$(login "$PA") && ok "A giriş (OTP bypass) uid=${A#*|}" || fail "A giriş"
B=$(login "$PB") && ok "B giriş uid=${B#*|}" || fail "B giriş"
TA=${A%%|*}; UA=${A#*|}; TB=${B%%|*}; UB=${B#*|}
[ $FAILS -eq 0 ] || { echo "SONUÇ: giriş başarısız, durduruldu"; exit 1; }

rest() { # rest <token> <method> <path> [json] [prefer] — boş gövde/bağlantı kopması (GitHub runner ↔ Timeweb DDoS filtresi,
  # 04.09 ilk CI koşusu) için 3 deneme; yalnız ağ hatasında tekrarlar (HTTP cevabı geldiyse olduğu gibi döner).
  local i out code
  for i in 1 2 3; do
    out=$(curl -s -m 25 -w '\n%{http_code}' -X "$2" "$BASE/rest/v1/$3" -H "apikey: $ANON" -H "Authorization: Bearer $1" -H "Content-Type: application/json" ${5:+-H "Prefer: $5"} ${4:+-d "$4"})
    code=${out##*$'\n'}; out=${out%$'\n'*}
    if [ "$code" != "000" ] && [ "$code" != "" ]; then printf '%s' "$out"; return 0; fi
    echo "  ↻ $2 $3: ağ hatası (deneme $i/3)" >&2; sleep 3
  done
  printf '%s' "$out"
}

# ---------- 1b) Sihirbaz yan dalı: «Şehrim listede yok» — users satırı HENÜZ YOKKEN (sihirbaz 3. adım) ----------
# 29.07→04.09 FK users(id) yüzünden 409 veriyordu, uygulama yutuyordu (Алёна vakası); FK auth.users'a alındı.
N=$(psql "select count(*) from public.users where id='$UA'"); [ "${N:-0}" -eq 0 ] || fail "ön koşul: A'nın users satırı silinmemiş ($N)"
r=$(rest "$TA" POST "city_requests" "{\"user_id\":\"$UA\",\"city_text\":\"E2E-Kazan\"}" "return=minimal")
[ -z "$r" ] && ok "şehir talebi (users satırı yokken) kaydedildi" || fail "şehir talebi → ${r:0:160}"
N=$(psql "select count(*) from public.city_requests where user_id='$UA' and city_text='E2E-Kazan'"); [ "${N:-0}" -eq 1 ] && ok "şehir talebi DB'de ($N)" || fail "şehir talebi DB'de yok"

# ---------- 2) Kayıt (profile_setup ile birebir upsert) ----------
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for who in A B; do
  if [ $who = A ]; then T=$TA; U=$UA; NAME="E2E Alpha"; G=male; AGE=30; else T=$TB; U=$UB; NAME="E2E Beta"; G=female; AGE=28; fi
  r=$(rest "$T" POST "users" "{\"id\":\"$U\",\"name\":\"$NAME\",\"age\":$AGE,\"gender\":\"$G\",\"city_id\":\"$MOSCOW\",\"interests\":[],\"min_age\":21,\"max_age\":60,\"consent_given_at\":\"$NOW\",\"consent_version\":\"2026-07-08\"}" "resolution=merge-duplicates,return=minimal")
  [ -z "$r" ] && ok "$who kayıt (users upsert)" || fail "$who kayıt → ${r:0:160}"
done
psql "update public.users set selfie_status='approved', is_test_user=true where id in ('$UA','$UB')" >/dev/null && ok "selfie onayı (servis)" || fail "selfie onayı"

# ---------- 3) A davet oluşturur ----------
EXP=$(date -u -v+1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+1 day' +%Y-%m-%dT%H:%M:%SZ)
EVT=$(date -u -v+2d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+2 day' +%Y-%m-%dT%H:%M:%SZ)
r=$(rest "$TA" POST "invitations?select=id" "{\"owner_id\":\"$UA\",\"flow_type\":\"invite\",\"category\":\"food\",\"title\":\"E2E test daveti\",\"venue_name\":\"E2E Cafe\",\"event_date\":\"$EVT\",\"expires_at\":\"$EXP\",\"city_id\":\"$MOSCOW\",\"slots_total\":1,\"status\":\"active\"}" "return=representation")
INV=$(echo "$r" | json "d[0]['id']"); [ -n "$INV" ] && ok "davet oluşturuldu $INV" || fail "davet → ${r:0:200}"

# ---------- 4) B başvurur ----------
r=$(rest "$TB" POST "applications?select=id" "{\"invitation_id\":\"$INV\",\"applicant_id\":\"$UB\",\"status\":\"pending\"}" "return=representation")
APP=$(echo "$r" | json "d[0]['id']"); [ -n "$APP" ] && ok "başvuru $APP" || fail "başvuru → ${r:0:200}"
# B'nin feed'de daveti görmesi (RLS + feed filtresi: karşı cins, aktif)
r=$(rest "$TB" GET "invitations?id=eq.$INV&select=id,status")
echo "$r" | grep -q "$INV" && ok "B daveti görüyor (RLS)" || fail "B davet göremiyor → ${r:0:120}"

# ---------- 5) A seçer → match ----------
r=$(rest "$TA" POST "rpc/match_and_select" "{\"p_application_id\":\"$APP\",\"p_invitation_id\":\"$INV\"}")
MATCH=$(echo "$r" | tr -d '"'); echo "$MATCH" | grep -qE '^[0-9a-f-]{36}$' && ok "seçim → match $MATCH" || fail "match_and_select → ${r:0:200}"

# ---------- 6) Mesajlar ----------
r=$(rest "$TA" POST "messages?select=id" "{\"match_id\":\"$MATCH\",\"sender_id\":\"$UA\",\"content\":\"E2E ping\"}" "return=representation"); echo "$r" | grep -q '"id"' && ok "A mesaj" || fail "A mesaj → ${r:0:160}"
r=$(rest "$TB" POST "messages?select=id" "{\"match_id\":\"$MATCH\",\"sender_id\":\"$UB\",\"content\":\"E2E pong\"}" "return=representation"); echo "$r" | grep -q '"id"' && ok "B mesaj" || fail "B mesaj → ${r:0:160}"
# B'nin sohbet özeti RPC'si (my_chat_summaries) kendi sohbetini görmeli
r=$(rest "$TB" POST "rpc/my_chat_summaries" "{}"); echo "$r" | grep -q "$MATCH" && ok "my_chat_summaries sohbeti listeliyor" || fail "my_chat_summaries → ${r:0:160}"

# ---------- 7) Sunucu tarafı doğrulamalar ----------
N=$(psql "select count(*) from public.notifications where user_id='$UA' and type='new_application'"); [ "${N:-0}" -ge 1 ] && ok "A'ya new_application bildirimi ($N)" || fail "A new_application bildirimi yok"
N=$(psql "select count(*) from public.notifications where user_id='$UB' and type='selected'"); [ "${N:-0}" -ge 1 ] && ok "B'ye selected bildirimi ($N)" || fail "B selected bildirimi yok"
N=$(psql "select count(*) from public.messages where match_id='$MATCH'"); [ "${N:-0}" -eq 2 ] && ok "2 mesaj kayıtlı" || fail "mesaj sayısı $N"
# push_log asenkron yazılır (bildirim → edge). Sunucu içinde betik 2 sn'de bittiği için (04.09) tek sorgu yarışı
# kaybediyordu; 20 sn'ye kadar 2 sn'de bir bakılır.
N=0; for _ in 1 2 3 4 5 6 7 8 9 10; do
  N=$(psql "select count(*) from public.push_log where user_id in ('$UA','$UB') and sent_at > now()-interval '10 minutes'")
  [ "${N:-0}" -ge 1 ] && break; sleep 2
done
[ "${N:-0}" -ge 1 ] && ok "push hattı tetiklendi (push_log $N, token yok → no_token beklenir)" || fail "push_log kaydı yok (20 sn beklendi)"
N=$(psql "select free_applications_used from public.users where id='$UB'"); [ "${N:-0}" -ge 1 ] && ok "ücretsiz hak sayacı arttı ($N)" || fail "free_applications_used artmadı ($N)"
# Kabul edilen başvuran daveti feed'de görmemeli (feed_visibility_rules) — hide kuralı RLS değil istemci; burada yalnız status kontrol
S=$(psql "select status from public.applications where id='$APP'"); [ "$S" = "accepted" ] && ok "başvuru accepted" || fail "başvuru durumu $S"
S=$(psql "select status from public.invitations where id='$INV'"); ok "davet durumu: $S"

# ---------- 8) Temizlik ----------
cleanup && ok "temizlik yapıldı (E2E davet/başvuru/match/mesaj/bildirim silindi)"
echo; if [ $FAILS -eq 0 ]; then echo "SONUÇ: KRİTİK YOL E2E GEÇTİ ✅"; exit 0; else echo "SONUÇ: $FAILS adım BAŞARISIZ ❌"; exit 1; fi
