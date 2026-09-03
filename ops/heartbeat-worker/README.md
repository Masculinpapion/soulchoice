# soulchoice-heartbeat — dead-man switch (03.09.2026)

Cloudflare Worker (Mustafa'nın Cloudflare hesabı, proje klasörü Mac'te `~/Projects/soulchoice-heartbeat`).

- Sunucu: `/root/monitoring/checks.sh` §23 her koşuda `GET /ping?t=<PING_SECRET>` atar
  (URL `/root/monitoring/heartbeat.url`, 0600).
- Worker cron `*/10`: son ping 30 dk'dan eskiyse Telegram CRIT (bir kez), ping dönünce OK.
- `/status` → `{last_ping_age_min, alerted}`; `/test?t=…` → Telegram test mesajı.
- Secrets (wrangler secret): PING_SECRET, TG_TOKEN, TG_CHAT (= /root/monitoring/.env ile aynı bot/kanal).
- Deploy: `cd ~/Projects/soulchoice-heartbeat && npx -y wrangler@3 deploy` (Node 20).
