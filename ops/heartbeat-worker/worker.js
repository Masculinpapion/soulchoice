// SoulChoice ops Worker (03.09.2026) — Cloudflare, Mustafa'nın mevcut hesabı. İki görev:
//  1) DEAD-MAN: sunucudaki checks.sh her 15 dk GET /ping?t=<PING_SECRET>; cron (*/10) 30 dk sessizlikte
//     Telegram CRIT (alarm botu), ping dönünce OK. (kalite teşhisi A7)
//  2) NÖBET KÖPRÜSÜ: @soulchoice_nobet_bot webhook'u → POST /tg (Telegram secret başlığı doğrulanır);
//     yalnız ALLOWED_TG_ID'den gelen mesajlar KV gelen kutusuna yazılır ve «aldım» yanıtı gider;
//     bulut rutini GET /inbox?t=<INBOX_SECRET> ile okur, POST /inbox/ack ile işaretler,
//     cevabı POST /reply ile yazar (bot token Worker'da kalır). Mac/VPN'e bağımlılık yok.
//     Sunucu tarafı rapor: https://soulchoice.app/nobet/<token>/report.json (nginx /nobet/api/ → bu Worker).
const STALE_MS = 30 * 60 * 1000;

async function tgSend(token, chatId, text) {
  const r = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text }),
  });
  return r.ok;
}

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json' } });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const secretOk = (name) => url.searchParams.get('t') === env[name];

    // ---- dead-man ----
    if (url.pathname === '/ping') {
      if (!secretOk('PING_SECRET')) return new Response('forbidden', { status: 403 });
      await env.HB.put('last', String(Date.now()));
      return new Response('ok');
    }
    if (url.pathname === '/test') {
      if (!secretOk('PING_SECRET')) return new Response('forbidden', { status: 403 });
      const ok = await tgSend(env.TG_TOKEN, env.TG_CHAT, '🧪 dead-man test: Cloudflare Worker → Telegram yolu çalışıyor (soulchoice-heartbeat).');
      return new Response(ok ? 'sent' : 'telegram_failed', { status: ok ? 200 : 502 });
    }
    if (url.pathname === '/status') {
      const last = Number(await env.HB.get('last')) || 0;
      const ageMin = last ? Math.round((Date.now() - last) / 60000) : null;
      const inbox = JSON.parse((await env.HB.get('inbox')) || '[]');
      return json({ last_ping_age_min: ageMin, alerted: (await env.HB.get('alerted')) === '1', inbox_pending: inbox.length });
    }

    // ---- Nöbet köprüsü ----
    if (url.pathname === '/tg' && request.method === 'POST') {
      // Telegram, setWebhook'ta verilen secret_token'ı bu başlıkla gönderir.
      if (request.headers.get('x-telegram-bot-api-secret-token') !== env.TG_WEBHOOK_SECRET) {
        return new Response('forbidden', { status: 403 });
      }
      let update;
      try { update = await request.json(); } catch (_) { return new Response('bad', { status: 400 }); }
      const msg = update.message || update.edited_message;
      if (!msg || !msg.text) return new Response('ignored');
      const fromId = String(msg.from?.id ?? '');
      const chatId = msg.chat?.id;
      if (!env.ALLOWED_TG_ID) {
        // Kurulum: ilk gönderenin kimliğini kaydet, sahibi Claude oturumundan onaylayacak.
        await env.HB.put('first_sender', JSON.stringify({ id: fromId, name: msg.from?.first_name, username: msg.from?.username, at: Date.now() }));
        await tgSend(env.NOBET_TOKEN, chatId, 'Nöbet botu kurulumda: kimliğin kaydedildi, onay bekleniyor.');
        return new Response('pending');
      }
      if (fromId !== env.ALLOWED_TG_ID) return new Response('ignored'); // yabancı: sessizce düş
      const inbox = JSON.parse((await env.HB.get('inbox')) || '[]');
      inbox.push({ id: msg.message_id, chat_id: chatId, text: msg.text.slice(0, 2000), at: (msg.date || 0) * 1000 });
      while (inbox.length > 50) inbox.shift();
      await env.HB.put('inbox', JSON.stringify(inbox));
      await tgSend(env.NOBET_TOKEN, chatId, '⏳ Nöbet aldı. Bulut rutini bakıp burada cevaplayacak (en geç 1 saat; acil alarmlar ayrıca gelir).');
      return new Response('queued');
    }
    // Rutinin cevabı: bot token Worker'da kalır, rutin yalnız INBOX_SECRET bilir.
    if (url.pathname === '/reply' && request.method === 'POST') {
      if (!secretOk('INBOX_SECRET')) return new Response('forbidden', { status: 403 });
      const { chat_id, text } = await request.json();
      const ok = await tgSend(env.NOBET_TOKEN, chat_id || env.ALLOWED_TG_ID, String(text || '').slice(0, 3900));
      return json({ ok });
    }
    if (url.pathname === '/inbox' && request.method === 'GET') {
      if (!secretOk('INBOX_SECRET')) return new Response('forbidden', { status: 403 });
      const inbox = JSON.parse((await env.HB.get('inbox')) || '[]');
      const first = JSON.parse((await env.HB.get('first_sender')) || 'null');
      return json({ messages: inbox, first_sender: first, allowed_id: env.ALLOWED_TG_ID || null });
    }
    if (url.pathname === '/inbox/ack' && request.method === 'POST') {
      if (!secretOk('INBOX_SECRET')) return new Response('forbidden', { status: 403 });
      const { ids } = await request.json();
      const inbox = JSON.parse((await env.HB.get('inbox')) || '[]');
      const keep = inbox.filter((m) => !(ids || []).includes(m.id));
      await env.HB.put('inbox', JSON.stringify(keep));
      return json({ remaining: keep.length });
    }
    return new Response('soulchoice-ops', { status: 404 });
  },

  async scheduled(_event, env) {
    const last = Number(await env.HB.get('last')) || 0;
    const alerted = (await env.HB.get('alerted')) === '1';
    const age = Date.now() - last;
    if (last === 0) return;
    if (age > STALE_MS && !alerted) {
      const ok = await tgSend(env.TG_TOKEN, env.TG_CHAT, `🔴 CRIT dead-man: SoulChoice sunucu alarm sistemi (checks.sh) ${Math.round(age / 60000)} dakikadır ping atmıyor — sunucu/cron/ağ kontrol et.`);
      if (ok) await env.HB.put('alerted', '1');
    } else if (age <= STALE_MS && alerted) {
      await tgSend(env.TG_TOKEN, env.TG_CHAT, "✅ dead-man düzeldi: checks.sh ping'i yeniden geliyor.");
      await env.HB.put('alerted', '0');
    }
  },
};
