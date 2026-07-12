#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# face_focus.py — user_photos için yüz odak noktası tespiti (YuNet).
# Cron: */2 dk, flock ile tekil. Yeni yüklenen fotoğraflar birkaç dk içinde
# odak kazanır; uygulama o ana kadar topCenter fallback gösterir.
# face_focus_x: null=işlenmedi, -1=yüz bulunamadı (fallback), 0..1=yüz merkezi.
import subprocess, urllib.request, tempfile, os, sys, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(HERE, "yunet.onnx")
LIMIT = 60

import cv2  # venv: opencv-python-headless

def psql(sql):
    r = subprocess.run(
        ["docker", "exec", "-i", "supabase-db", "psql", "-U", "supabase_admin",
         "-d", "postgres", "-tA", "-c", sql],
        capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[:400])
    return [l for l in r.stdout.splitlines() if l.strip()]

det = cv2.FaceDetectorYN.create(MODEL, "", (320, 320), score_threshold=0.7)

rows = psql("select p.id||'|'||p.url from public.user_photos p "
            "where p.face_focus_x is null and p.is_selfie=false "
            f"order by p.id limit {LIMIT};")
if not rows:
    sys.exit(0)

done = miss = err = 0
for line in rows:
    pid, url = line.split("|", 1)
    local = url.replace("https://soulchoice.app", "http://localhost:8000")
    try:
        with urllib.request.urlopen(local, timeout=20) as resp, \
             tempfile.NamedTemporaryFile(suffix=".img", delete=False) as tf:
            tf.write(resp.read()); tmp = tf.name
        img = cv2.imread(tmp); os.unlink(tmp)
        if img is None:
            raise RuntimeError("decode edilemedi")
        h, w = img.shape[:2]
        scale = 640.0 / max(h, w)
        inp = cv2.resize(img, (int(w*scale), int(h*scale))) if scale < 1 else img
        scale = min(scale, 1.0)
        det.setInputSize((inp.shape[1], inp.shape[0]))
        _, faces = det.detect(inp)
        if faces is None or len(faces) == 0:
            psql(f"update public.user_photos set face_focus_x=-1, face_focus_y=-1 where id='{pid}';")
            miss += 1
        else:
            best = max(faces, key=lambda f: f[2]*f[3])
            cx = (best[0] + best[2]/2) / scale / w
            cy = (best[1] + best[3]/2) / scale / h
            cx = min(max(cx, 0.0), 1.0); cy = min(max(cy, 0.0), 1.0)
            psql(f"update public.user_photos set face_focus_x={cx:.4f}, face_focus_y={cy:.4f} where id='{pid}';")
            done += 1
    except Exception as e:
        # İndirilemeyen/çözülemeyen dosya: kalıcı -1 (fallback) — cron'u sonsuz döngüye sokma
        err += 1
        print(f"{datetime.datetime.now():%H:%M} HATA {pid}: {e} → -1 işaretlendi", flush=True)
        try:
            psql(f"update public.user_photos set face_focus_x=-1, face_focus_y=-1 where id='{pid}';")
        except Exception:
            pass

print(f"{datetime.datetime.now():%Y-%m-%d %H:%M} odak={done} yüzyok={miss} hata={err}", flush=True)
