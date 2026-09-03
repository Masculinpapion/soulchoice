// SoulChoice dead-man switch (03.09.2026) — Cloudflare Worker (Mustafa'nın mevcut hesabı).
// Sunucudaki /root/monitoring/checks.sh her 15 dk GET /ping?t=<PING_SECRET> atar.
// Cron (*/10) son ping'e bakar: 30 dk sessizlik → Telegram CRIT (bir kez), ping dönünce OK.
// Amaç: alarm sistemi susarsa sessizlik "sağlık" gibi görünmesin (kalite teşhisi A7).
const STALE_MS = 30 * 60 * 1000;

async function tg(env, text) {
  const r = await fetch(`https://api.telegram.org/bot${env.TG_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ chat_id: env.TG_CHAT, text }),
  });
  return r.ok;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/ping') {
      if (url.searchParams.get('t') !== env.PING_SECRET) return new Response('forbidden', { status: 403 });
      await env.HB.put('last', String(Date.now()));
      return new Response('ok');
    }
    if (url.pathname === '/test') {
      // Kurulum kanıtı: Telegram yolunun çalıştığını tek mesajla gösterir (secret şart).
      if (url.searchParams.get('t') !== env.PING_SECRET) return new Response('forbidden', { status: 403 });
      const ok = await tg(env, '🧪 dead-man test: Cloudflare Worker → Telegram yolu çalışıyor (soulchoice-heartbeat).');
      return new Response(ok ? 'sent' : 'telegram_failed', { status: ok ? 200 : 502 });
    }
    if (url.pathname === '/status') {
      const last = Number(await env.HB.get('last')) || 0;
      const ageMin = last ? Math.round((Date.now() - last) / 60000) : null;
      return new Response(JSON.stringify({ last_ping_age_min: ageMin, alerted: (await env.HB.get('alerted')) === '1' }), {
        headers: { 'content-type': 'application/json' },
      });
    }
    return new Response('soulchoice-heartbeat', { status: 404 });
  },

  async scheduled(_event, env) {
    const last = Number(await env.HB.get('last')) || 0;
    const alerted = (await env.HB.get('alerted')) === '1';
    const age = Date.now() - last;
    if (last === 0) return; // henüz hiç ping gelmedi (kurulum)
    if (age > STALE_MS && !alerted) {
      const ok = await tg(env, `🔴 CRIT dead-man: SoulChoice sunucu alarm sistemi (checks.sh) ${Math.round(age / 60000)} dakikadır ping atmıyor — sunucu/cron/ağ kontrol et.`);
      if (ok) await env.HB.put('alerted', '1');
    } else if (age <= STALE_MS && alerted) {
      await tg(env, "✅ dead-man düzeldi: checks.sh ping'i yeniden geliyor.");
      await env.HB.put('alerted', '0');
    }
  },
};
