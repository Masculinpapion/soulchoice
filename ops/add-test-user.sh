#!/usr/bin/env bash
# ============================================================================
# ops/add-test-user.sh — test kullanıcısı ekleme (canlılık simülasyonu v1)
# is_test_user bayrağını YALNIZ bu script setler; selfie approved doğar,
# moderasyona girmez. İlk daveti de oluşturur (simülasyon fonksiyonu sonrasını
# kendisi döndürür).
#
# Kullanım:
#   ./add-test-user.sh --name "Anna" --gender female --city "Moskova" --age 29 \
#                      --photos ./photos/anna --bio "..." [--job "..."] [--edu "..."]
#
# Gereksinim: ssh timeweb_prod anahtarı; fotoğraflar jpg/png, ilki primary.
# ============================================================================
set -euo pipefail

SSH="ssh -i $HOME/.ssh/timeweb_prod root@89.169.1.127"
SQL="docker exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1"

NAME="" GENDER="" CITY="" AGE="" PHOTOS="" BIO="" JOB="" EDU=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2;; --gender) GENDER="$2"; shift 2;;
    --city) CITY="$2"; shift 2;; --age) AGE="$2"; shift 2;;
    --photos) PHOTOS="$2"; shift 2;; --bio) BIO="$2"; shift 2;;
    --job) JOB="$2"; shift 2;; --edu) EDU="$2"; shift 2;;
    *) echo "bilinmeyen arg: $1"; exit 1;;
  esac
done
[[ -z "$NAME" || -z "$GENDER" || -z "$CITY" || -z "$AGE" || -z "$PHOTOS" ]] && {
  echo "zorunlu: --name --gender --city --age --photos"; exit 1; }

UID_NEW=$(uuidgen | tr 'A-Z' 'a-z')

# Sıradaki boş test telefonu (+79991112XXX serisi)
PHONE=$($SSH "$SQL -t -c \"select '+7999111'||lpad((coalesce(max(right(phone,4)::int),2000)+1)::text,4,'0') from auth.users where phone like '+7999111%';\"" | tr -d ' ')

echo ">> id=$UID_NEW phone=$PHONE"

# ── 1) auth.users + public.users ─────────────────────────────────────────────
# DOĞRULAMA-A (ilk kullanımda): auth.users kolon seti mevcut test satırıyla
# birebir kıyaslanacak (GoTrue sürüm farkı sürprizi olmasın).
$SSH "$SQL" <<SQLEOF
begin;
insert into auth.users (instance_id, id, aud, role, phone, phone_confirmed_at,
                        encrypted_password, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '$UID_NEW', 'authenticated',
        'authenticated', '$PHONE', now(), '', now(), now());

insert into public.users (id, phone, name, age, gender, city_id, bio, job, education,
                          verified, verified_at, selfie_status, is_test_user,
                          consent_given_at, consent_version, created_at, last_active_at)
select '$UID_NEW', '$PHONE', '$NAME', $AGE, '$GENDER', c.id,
       nullif('$BIO',''), nullif('$JOB',''), nullif('$EDU',''),
       true, now(), 'approved', true,
       now(), '2026-07-08', now() - interval '3 days', now()
from public.cities c where c.name = '$CITY';
commit;
SQLEOF

# ── 2) Fotoğraflar: profile-photos bucket'ına yükle + user_photos satırları ──
# Yol düzeni mevcut kalıpla uyumlu: <şehir-kısaltma>/<dosya>
CITY_DIR=$(echo "$CITY" | tr 'A-ZĞÜŞİÖÇ' 'a-zğüşiöç' | cut -c1-3)
ORDER=0
for f in "$PHOTOS"/*.{jpg,jpeg,png}; do
  [[ -e "$f" ]] || continue
  BASE="test_${UID_NEW:0:8}_$(basename "$f")"
  scp -i "$HOME/.ssh/timeweb_prod" "$f" "root@89.169.1.127:/tmp/$BASE"
  # storage API ile yükleme (service key sunucudaki .env'den; xattr'ları API kendisi yazar
  # — dosyayı diske elle KOYMA, bkz reference_storage_xattr_restore)
  $SSH "KEY=\$(grep '^SERVICE_ROLE_KEY=' /root/supabase/docker/.env | cut -d= -f2-); \
    curl -sS -X POST 'http://localhost:8000/storage/v1/object/profile-photos/$CITY_DIR/$BASE' \
      -H \"Authorization: Bearer \$KEY\" -H 'Content-Type: image/jpeg' \
      --data-binary @/tmp/$BASE && rm /tmp/$BASE"
  IS_PRIMARY=$([[ $ORDER -eq 0 ]] && echo true || echo false)
  $SSH "$SQL -c \"insert into public.user_photos (user_id, url, is_primary, is_selfie, moderation_status, order_index)
    values ('$UID_NEW', 'https://soulchoice.app/storage/v1/object/public/profile-photos/$CITY_DIR/$BASE',
            $IS_PRIMARY, false, 'approved', $ORDER);\""
  ORDER=$((ORDER+1))
done

# ── 3) İlk davet (başlık/mekan preset; simülasyon fonksiyonu sonrasını çevirir)
$SSH "$SQL" <<SQLEOF
insert into public.invitations (owner_id, flow_type, category, title, venue_name,
                                event_date, city_id, slots_total, status,
                                created_at, expires_at)
select '$UID_NEW',
       case when '$GENDER'='male' then 'invite' else 'request' end,
       (array['restaurant','bar','concert'])[1+floor(random()*3)::int],
       'PLACEHOLDER — elle/preset doldurulacak',
       'PLACEHOLDER',
       now() + interval '1 day' + (random() * interval '6 hours'),
       c.id, 1, 'active',
       now() - (random() * interval '90 minutes'),
       now() + interval '20 hours' + (random() * interval '4 hours')
from public.cities c where c.name = '$CITY';
SQLEOF

echo ">> TAMAM: $NAME ($GENDER, $CITY) — $ORDER foto. Davet başlığı PLACEHOLDER: elle güncelle."
