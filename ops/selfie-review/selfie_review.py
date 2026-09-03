#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# selfie_review.py — SELFİE OTO-İNCELEME (04.09.2026). Sunucu: /root/ops/selfie-review/, cron */1 dk, flock.
# Akış (Mustafa 22.08 revizyonu): bekleme YOK — pending selfie düşer düşmez incelenir.
#   • selfide tek/baskın yüz + profil fotoğraflarından en az biriyle SFace kosinüs benzerliği ≥ APPROVE
#     → anında 'approved' (trg_notify_selfie_status push'u atar) + audit_log 'selfie_auto_approve'
#   • aksi hâlde pending KALIR + audit_log 'selfie_auto_flag' + Telegram WARN → insan bakar (RED DAİMA İNSAN)
# Veri sunucu dışına ÇIKMAZ (localhost storage + yerel OpenCV) → gizlilik metni değişmez.
# Aynı selfie URL'si iki kez incelenmez; kullanıcı yeni selfie yüklerse (yeni URL) yeniden incelenir.
# Kalibrasyon: `selfie_review.py --calibrate` → onaylı kullanıcıların skor dağılımını yazar, HİÇBİR ŞEY YAZMAZ.
import subprocess, urllib.request, tempfile, os, sys, json, datetime, shlex

HERE = os.path.dirname(os.path.abspath(__file__))
YUNET = os.path.join(HERE, "yunet.onnx")
SFACE = os.path.join(HERE, "sface.onnx")
ALERT = "/root/monitoring/alert.sh"
APPROVE = 0.40      # SFace kosinüs (OpenCV referans eşiği 0.363; biraz muhafazakâr)
MIN_FACE_FRAC = 0.12 # selfide yüz genişliği / görüntü genişliği — çok uzak/küçük yüz onaylanmaz
LIMIT = 30
CALIB = "--calibrate" in sys.argv

import cv2  # venv: opencv-python-headless (face-focus ile aynı venv)
try:
    cv2.utils.logging.setLogLevel(cv2.utils.logging.LOG_LEVEL_ERROR)  # her koşuda 'setPreferableTarget' WARN basmasın (log şişmesin)
except Exception:
    pass

def psql(sql):
    r = subprocess.run(["docker", "exec", "-i", "supabase-db", "psql", "-U", "supabase_admin",
                        "-d", "postgres", "-tA", "-F", "\t", "-c", sql],
                       capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[:400])
    return [l for l in r.stdout.splitlines() if l.strip()]

def q(s):  # SQL string literal
    return "'" + str(s).replace("'", "''") + "'"

det = cv2.FaceDetectorYN.create(YUNET, "", (320, 320), score_threshold=0.5)  # onayı SFace benzerliği kapılar; tespit gevşek olabilir
rec = cv2.FaceRecognizerSF.create(SFACE, "")

STORAGE_ROOT = "/root/volumes/storage/stub/stub"   # storage-api dosya arka ucu: <bucket>/<key>/<versiyon-id>

def disk_path(url):
    """selfies kovası özel: public URL 400 döner → dosyayı diskten oku (storage-api düzeni)."""
    key = url.split("/storage/v1/object/public/", 1)[1]
    d = os.path.join(STORAGE_ROOT, key)
    files = [f for f in os.listdir(d) if not f.endswith(".json")]
    if not files:
        raise RuntimeError("diskte nesne yok: " + key)
    return os.path.join(d, sorted(files)[-1])

def load(url):
    if "/object/public/selfies/" in url:
        img = cv2.imread(disk_path(url))
    else:
        local = url.replace("https://soulchoice.app", "http://localhost:8000")
        with urllib.request.urlopen(local, timeout=20) as resp, tempfile.NamedTemporaryFile(suffix=".img", delete=False) as tf:
            tf.write(resp.read()); tmp = tf.name
        img = cv2.imread(tmp); os.unlink(tmp)
    if img is None:
        raise RuntimeError("decode edilemedi")
    h, w = img.shape[:2]
    s = 1024.0 / max(h, w)
    return cv2.resize(img, (int(w * s), int(h * s))) if s < 1 else img

def faces_of(img):
    det.setInputSize((img.shape[1], img.shape[0]))
    _, faces = det.detect(img)
    return [] if faces is None else sorted(faces, key=lambda f: -(f[2] * f[3]))

ROTS = (None, cv2.ROTATE_90_CLOCKWISE, cv2.ROTATE_180, cv2.ROTATE_90_COUNTERCLOCKWISE)

def best_orientation(img):
    """Uygulama EXIF'i siler (23.08 paketi) → telefon selfieleri 90° yatık gelebilir (kalibrasyon 04.09:
    8 onaylıdan 4'ü). Dört döndürmeyi dener, en yüksek güvenli yüzün bulunduğu yönü döndürür."""
    best = (None, [], -1.0)
    for rot in ROTS:
        cand = img if rot is None else cv2.rotate(img, rot)
        fs = faces_of(cand)
        if fs and float(fs[0][-1]) > best[2]:
            best = (cand, fs, float(fs[0][-1]))
    return best[0], best[1]

def feat(img, face):
    return rec.feature(rec.alignCrop(img, face))

def review(uid, selfie_url, photo_urls):
    """→ (karar, skor, sebep)  karar ∈ approve|flag"""
    simg, sf = best_orientation(load(selfie_url))
    if not sf:
        return "flag", 0.0, "selfide yüz yok"
    big = sf[0]
    if big[2] / simg.shape[1] < MIN_FACE_FRAC:
        return "flag", 0.0, f"selfide yüz çok küçük ({big[2] / simg.shape[1]:.2f})"
    if len(sf) > 1 and sf[1][2] * sf[1][3] > 0.3 * big[2] * big[3]:
        return "flag", 0.0, f"selfide {len(sf)} yüz"
    sfeat = feat(simg, big)
    best, nface = -1.0, 0
    for url in photo_urls:
        try:
            pimg, pf = best_orientation(load(url))
        except Exception:
            continue
        for f in pf[:2]:
            nface += 1
            score = float(rec.match(sfeat, feat(pimg, f), cv2.FaceRecognizerSF_FR_COSINE))
            best = max(best, score)
    if nface == 0:
        return "flag", 0.0, "profil fotoğraflarında yüz yok"
    if best >= APPROVE:
        return "approve", best, f"sface={best:.3f} profil_yüz={nface}"
    return "flag", best, f"düşük benzerlik sface={best:.3f} profil_yüz={nface}"

if CALIB:
    rows = psql("select u.id, coalesce(u.name,''), (select url from public.user_photos where user_id=u.id and is_selfie order by created_at desc limit 1), "
                "(select string_agg(url, ' ') from public.user_photos where user_id=u.id and not is_selfie) "
                "from public.users u where u.selfie_status='approved' and not u.is_test_user "
                "and exists (select 1 from public.user_photos where user_id=u.id and is_selfie) order by u.created_at desc limit 60")
    for line in rows:
        uid, name, surl, purls = (line.split("\t") + ["", "", "", ""])[:4]
        try:
            d, s, why = review(uid, surl, purls.split())
            print(f"{uid[:8]} {name[:14]:14s} {d:7s} {s:.3f} {why}")
        except Exception as e:
            print(f"{uid[:8]} {name[:14]:14s} HATA {e}")
    sys.exit(0)

rows = psql("select u.id, coalesce(u.name,''), s.url, "
            "coalesce((select string_agg(url, ' ') from public.user_photos where user_id=u.id and not is_selfie), '') "
            "from public.users u "
            "join lateral (select url from public.user_photos where user_id=u.id and is_selfie order by created_at desc limit 1) s on true "
            "where u.selfie_status='pending' and not u.is_test_user and not u.is_deleted "
            "and not exists (select 1 from public.audit_log a where a.target_id=u.id and a.action like 'selfie_auto_%' "
            "                and a.meta->>'selfie_url' = s.url) "
            f"order by u.created_at limit {LIMIT}")
if not rows:
    sys.exit(0)
ok = flag = err = 0
for line in rows:
    uid, name, surl, purls = (line.split("\t") + ["", "", "", ""])[:4]
    try:
        d, s, why = review(uid, surl, purls.split())
    except Exception as e:
        err += 1
        print(f"{datetime.datetime.now():%H:%M} HATA {uid[:8]}: {e} (sonraki koşuda tekrar)", flush=True)
        continue
    meta = json.dumps({"selfie_url": surl, "score": round(s, 3), "profile_photos": len(purls.split())}, ensure_ascii=False)
    if d == "approve":
        psql(f"update public.users set selfie_status='approved', selfie_rejected_reason=null where id={q(uid)} and selfie_status='pending';"
             f"insert into public.audit_log(actor, action, target_type, target_id, reason, meta) values ('selfie-auto-review','selfie_auto_approve','user',{q(uid)},{q(why)},{q(meta)}::jsonb);")
        ok += 1
    else:
        psql(f"insert into public.audit_log(actor, action, target_type, target_id, reason, meta) values ('selfie-auto-review','selfie_auto_flag','user',{q(uid)},{q(why)},{q(meta)}::jsonb);")
        subprocess.run([ALERT, "WARN", f"şüpheli selfie: {name[:20]} ({uid[:8]}) — {why}. Ops panelinden onayla/reddet (oto-red yok)."], timeout=30)
        flag += 1
    print(f"{datetime.datetime.now():%H:%M} {uid[:8]} {d} {why}", flush=True)
print(f"{datetime.datetime.now():%Y-%m-%d %H:%M} onay={ok} işaret={flag} hata={err}", flush=True)
