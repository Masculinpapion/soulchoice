#!/usr/bin/env bash
# RuStore Public API yardımcı — 07.09.2026
# Kullanım: rustore-api.sh token | versions | reviews | rating
# Anahtar: /root/.rustore_api.key (base64 PKCS8, tek satır), ID 2351031899 — asla stdout'a yazma.
set -euo pipefail
KEY_FILE=/root/.rustore_api.key
KEY_ID=2351031899
PKG=com.soulchoice.soulchoice
API=https://public-api.rustore.ru

get_token() {
  local ts pem sig resp
  ts=$(date +%Y-%m-%dT%H:%M:%S.%3N%:z)
  pem=$(mktemp)
  { echo "-----BEGIN PRIVATE KEY-----"; fold -w 64 "$KEY_FILE"; echo; echo "-----END PRIVATE KEY-----"; } > "$pem"
  sig=$(printf '%s%s' "$KEY_ID" "$ts" | openssl dgst -sha512 -sign "$pem" | base64 -w0)
  rm -f "$pem"
  resp=$(curl -s -m 20 -X POST "$API/public/auth/" -H 'Content-Type: application/json' \
    -d "{\"keyId\":\"$KEY_ID\",\"timestamp\":\"$ts\",\"signature\":\"$sig\"}")
  python3 - "$resp" <<'PY'
import sys, json
d = json.loads(sys.argv[1])
jwe = (d.get("body") or {}).get("jwe", "")
if not jwe:
    print("AUTH_FAIL", d.get("code"), d.get("message"), file=sys.stderr); sys.exit(2)
print(jwe)
PY
}

case "${1:-}" in
  token)
    get_token >/dev/null && echo "token OK" ;;
  versions)
    JWE=$(get_token)
    curl -s -m 20 "$API/public/v1/application/$PKG/version?page=0&size=${2:-5}" -H "Public-Token: $JWE" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print("code:", d.get("code"), d.get("message") or "")
for v in (d.get("body") or {}).get("content", []):
    print(" ", v.get("versionId"), v.get("versionName"), v.get("versionCode"), v.get("versionStatus"), v.get("publicationType"), "partial=", v.get("partialValue"))
' ;;
  reviews)
    JWE=$(get_token)
    curl -s -m 20 "$API/public/v1/application/$PKG/comment?page=0&size=${2:-5}" -H "Public-Token: $JWE" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print("code:", d.get("code"), d.get("message") or "")
body = d.get("body") or []
rows = body.get("content", []) if isinstance(body, dict) else body
for r in rows:
    print(" ", r.get("commentId"), r.get("appRating"), r.get("userName"), (r.get("commentDate") or "")[:10], r.get("appVersionCode"), "resp=", len(r.get("devResponses") or []), (r.get("commentText") or "")[:60].replace("\n"," "))
' ;;
  rating)
    JWE=$(get_token)
    curl -s -m 20 "$API/public/v1/application/$PKG/comment/statistic" -H "Public-Token: $JWE" | python3 -c '
import sys, json
d = json.load(sys.stdin); b = d.get("body") or {}
print("code:", d.get("code"), "avg=", b.get("averageUserRating"), "total=", b.get("totalRatings"), "ratings=", b.get("ratings"))
' ;;
  *) echo "usage: $0 token|versions|reviews|rating [size]"; exit 1 ;;
esac
