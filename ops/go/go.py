#!/usr/bin/env python3
# /root/soulchoice_go/go.py — SoulChoice /go?src=&to= takip yönlendiricisi (21.10.2026)
# 127.0.0.1:4921 · nginx: location = /go → proxy_pass
# Kayıt: go.db (sqlite). Telegram: yalnız insan tıklaması, aynı kaynak+hedef+IP 1 saatte 1 kez; botlar sessiz.
import os, re, sqlite3, time, json, urllib.parse, urllib.request, http.server, socketserver, threading, datetime

D = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(D, "go.db")
ENV = "/root/monitoring/.env"
TARGETS = {
    "play":    ("Google Play", "https://play.google.com/store/apps/details?id=com.soulchoice.soulchoice"),
    "rustore": ("RuStore",     "https://www.rustore.ru/catalog/app/com.soulchoice.soulchoice"),
    "site":    ("soulchoice.app", "https://soulchoice.app/"),
    "about":   ("Hakkında sayfası", "https://soulchoice.app/about"),
    "faq":     ("SSS sayfası", "https://soulchoice.app/faq"),
}
SRC_LABEL = {
    "llms": "llms.txt — yapay zekâ asistanı", "llmsfull": "llms-full.txt — yapay zekâ asistanı",
    "faq-ru": "SSS (RU)", "faq-en": "FAQ (EN)", "faq-tr": "SSS (TR)",
    "about-ru": "Hakkında (RU)", "about-en": "About (EN)", "about-tr": "Hakkında (TR)",
    "mcp": "MCP bağlayıcısı",
}
BOT = re.compile(r"bot|crawl|spider|slurp|gptbot|claude|perplexity|yandex|google|bingpreview|facebookexternalhit|curl|wget|python|httpx|go-http|headless|lighthouse|pingdom|uptime", re.I)
RECENT = {}  # (src,to,ip) -> epoch
LOCK = threading.Lock()

def env():
    v = {}
    try:
        for line in open(ENV, encoding="utf-8"):
            line = line.strip()
            if line.startswith("export "): line = line[7:]
            if "=" in line and not line.startswith("#"):
                k, val = line.split("=", 1); v[k.strip()] = val.strip().strip('"').strip("'")
    except Exception: pass
    return v.get("TELEGRAM_BOT_TOKEN", ""), v.get("TELEGRAM_CHAT_ID", "")

def db():
    c = sqlite3.connect(DB)
    c.execute("create table if not exists clicks(ts text, src text, target text, ua text, ip text, referer text, is_bot int)")
    return c

def device(ua):
    os_ = "iPhone" if "iPhone" in ua else "iPad" if "iPad" in ua else "Android" if "Android" in ua else "Mac" if "Macintosh" in ua else "Windows" if "Windows" in ua else "Linux" if "Linux" in ua else "?"
    br = "Yandex Browser" if "YaBrowser" in ua else "Edge" if "Edg/" in ua else "Opera" if "OPR/" in ua else "Chrome" if "Chrome/" in ua else "Safari" if "Safari/" in ua else "Firefox" if "Firefox/" in ua else "?"
    return f"{os_} · {br}"

def notify(src, to, ua, ref, ip):
    tok, chat = env()
    if not tok or not chat: return
    key = (src, to, ip); now = time.time()
    with LOCK:
        if now - RECENT.get(key, 0) < 3600: return
        RECENT[key] = now
        for k in [k for k, t in RECENT.items() if now - t > 7200]: RECENT.pop(k, None)
    host = urllib.parse.urlsplit(ref).netloc if ref else "—"
    msk = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=3))).strftime("%d.%m %H:%M")
    text = ("🔗 SoulChoice — mağaza tıklaması\n"
            f"📍 Kaynak: {SRC_LABEL.get(src, src)}\n"
            f"🏪 Hedef: {TARGETS[to][0]}\n"
            f"🌐 Yönlendiren: {host}\n"
            f"📱 Cihaz: {device(ua)}\n"
            f"🕒 {msk} MSK")
    data = urllib.parse.urlencode({"chat_id": chat, "text": text}).encode()
    def send():
        for i in range(3):
            try:
                urllib.request.urlopen(urllib.request.Request(f"https://api.telegram.org/bot{tok}/sendMessage", data=data), timeout=6); return
            except Exception: time.sleep(1 + i)
    threading.Thread(target=send, daemon=True).start()

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        u = urllib.parse.urlsplit(self.path)
        if u.path != "/go":
            self.send_response(404); self.end_headers(); return
        q = urllib.parse.parse_qs(u.query)
        src = (q.get("src", ["direct"])[0] or "direct")[:32]
        src = re.sub(r"[^a-z0-9_-]", "", src.lower()) or "direct"
        to = q.get("to", ["play"])[0].lower()
        if to not in TARGETS: to = "play"
        ua = self.headers.get("User-Agent", "")[:300]
        ref = self.headers.get("Referer", "")[:300]
        ip = (self.headers.get("X-Forwarded-For", "") or self.headers.get("X-Real-IP", "") or self.client_address[0]).split(",")[0].strip()[:64]
        is_bot = 1 if BOT.search(ua) or not ua else 0
        try:
            c = db(); c.execute("insert into clicks values(?,?,?,?,?,?,?)", (datetime.datetime.utcnow().isoformat(timespec="seconds"), src, to, ua, ip, ref, is_bot)); c.commit(); c.close()
        except Exception: pass
        if not is_bot: notify(src, to, ua, ref, ip)
        self.send_response(302)
        self.send_header("Location", TARGETS[to][1])
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Robots-Tag", "noindex, nofollow")
        self.end_headers()

if __name__ == "__main__":
    class S(socketserver.ThreadingMixIn, http.server.HTTPServer): daemon_threads = True
    S(("127.0.0.1", 4921), H).serve_forever()
