# soulchoice-heartbeat — dead-man switch (03.09.2026)

Cloudflare Worker (Mustafa'nın Cloudflare hesabı, proje klasörü Mac'te `~/Projects/soulchoice-heartbeat`).

- Sunucu: `/root/monitoring/checks.sh` §23 her koşuda `GET /ping?t=<PING_SECRET>` atar
  (URL `/root/monitoring/heartbeat.url`, 0600).
- Worker cron `*/10`: son ping 30 dk'dan eskiyse Telegram CRIT (bir kez), ping dönünce OK.
- `/status` → `{last_ping_age_min, alerted}`; `/test?t=…` → Telegram test mesajı.
- Secrets (wrangler secret): PING_SECRET, TG_TOKEN, TG_CHAT (= /root/monitoring/.env ile aynı bot/kanal).
- Deploy: `cd ~/Projects/soulchoice-heartbeat && npx -y wrangler@3 deploy` (Node 20).

## Nöbet köprüsü (03.09 akşam)
- Telegram bot @soulchoice_nobet_bot webhook → `POST https://hb.ahmtransfer.com/tg` (custom domain; Telegram workers.dev'i çözemedi).
- Yalnız `ALLOWED_TG_ID` (Worker secret) gönderenin mesajları KV `inbox`'a yazılır, «⏳ Nöbet aldı» yanıtı gider.
- Bulut rutini `GET /inbox?t=<INBOX_SECRET>` okur, `POST /inbox/ack {ids}` işaretler, cevabı Bot API ile yazar.
- Secrets: TG_WEBHOOK_SECRET, INBOX_SECRET (Mac: ~/.claude/secrets/soulchoice_ops_worker.env), NOBET_TOKEN, ALLOWED_TG_ID.
- Rutin SSH anahtarı: ~/.ssh/soulchoice_nobet_cloud (sunucu authorized_keys, yorum soulchoice-nobet-cloud-20260903).
