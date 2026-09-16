#!/usr/bin/env python3
"""App Store Connect inceleme bekçisi — GitHub Actions'ta koşar (17.09.2026).

Sebep: 12.09'da Apple, TestFlight beta 273 thread'ine 2.1 «Information Needed»
yazdı; mail gelmedi, ASC 5 gün açılmadı, 1.0.1 (275) kuyrukta bekledi.
Bu betik ASC API'den sürüm / inceleme gönderimi / beta inceleme durumlarını
okur ve tek satırlık JSON özet basar; sunucudaki asc-watch.sh özeti önceki
durumla karşılaştırıp Telegram'a yazar. Mesaj metinleri API'de YOK — durum
değişimi (REJECTED / UNRESOLVED_ISSUES) yeter: «ASC'ye bak» alarmı verir.

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (PEM içerik), ASC_APP_ID
"""
import json
import os
import sys
import time
import urllib.request

import jwt  # PyJWT + cryptography

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
P8 = os.environ["ASC_KEY_P8"]
APP_ID = os.environ.get("ASC_APP_ID", "6768422521")
BASE = "https://api.appstoreconnect.apple.com/v1"

now = int(time.time())
token = jwt.encode(
    {"iss": ISSUER, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
    P8, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"},
)


def get(path):
    req = urllib.request.Request(BASE + path, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


out = {"checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "versions": [], "submissions": [], "betas": []}

# 1) Mağaza sürümleri (appStoreState: WAITING_FOR_REVIEW, IN_REVIEW, REJECTED,
#    PENDING_DEVELOPER_RELEASE, READY_FOR_SALE, DEVELOPER_REJECTED ...)
v = get(f"/apps/{APP_ID}/appStoreVersions?limit=3&fields[appStoreVersions]=versionString,appStoreState")
for d in v.get("data", []):
    a = d["attributes"]
    # createdDate BİLEREK YOK: 17.09 nöbet rutini sürüm kaydı tarihini (11.05) gönderim tarihi sanıp «4 aydır bekliyor» dedi
    out["versions"].append({"v": a.get("versionString"), "state": a.get("appStoreState")})

# 2) İnceleme gönderimleri (state: READY_FOR_REVIEW, WAITING_FOR_REVIEW, IN_REVIEW,
#    UNRESOLVED_ISSUES, CANCELING, COMPLETING, COMPLETE)
try:
    s = get(f"/apps/{APP_ID}/reviewSubmissions?limit=3&fields[reviewSubmissions]=state,submittedDate,platform")
    for d in s.get("data", []):
        a = d["attributes"]
        out["submissions"].append({"id": d["id"][:8], "state": a.get("state"), "submitted": a.get("submittedDate")})
except Exception as e:  # uç nokta yetki dışıysa özet yine üretilsin
    out["submissions_error"] = str(e)[:120]

# 3) Beta (TestFlight) inceleme gönderimleri — açık/sorunlu olanlar (betaReviewState:
#    WAITING_FOR_REVIEW, IN_REVIEW, REJECTED). CI'ın her yüklediği build beta
#    incelemesine girmez; 12.09'daki 273 gibi gönderilenler burada görünür.
try:
    # betaAppReviewSubmissions uç noktası filter[build] ister (400) → son 10 build
    # üzerinden include ile alınır; beta incelemesine girmemiş build'ler atlanır.
    b = get(f"/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=10&fields[builds]=version,uploadedDate,betaAppReviewSubmission&include=betaAppReviewSubmission&fields[betaAppReviewSubmissions]=betaReviewState")
    states = {i["id"]: i["attributes"].get("betaReviewState") for i in b.get("included", []) if i["type"] == "betaAppReviewSubmissions"}
    for d in b.get("data", []):
        rel = (d.get("relationships", {}).get("betaAppReviewSubmission", {}) or {}).get("data") or {}
        st = states.get(rel.get("id"))
        if st:
            a = d["attributes"]
            out["betas"].append({"build": a.get("version"), "uploaded": a.get("uploadedDate"), "beta_state": st})
except Exception as e:
    out["betas_error"] = str(e)[:120]

json.dump(out, sys.stdout, ensure_ascii=False)
print()
