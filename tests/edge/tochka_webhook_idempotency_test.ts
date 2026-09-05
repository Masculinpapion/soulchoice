// 05.09.2026 — Точка webhook ÇİFT TESLİM sözleşmesi (05.09 açık iş #2).
// Koruma iki katmanlı ve ikisi de canlıda: (1) payments (operation_id, order_id) UNIQUE
// + `on conflict do nothing`, (2) gövdeye güvenilmez, durum bankadan yeniden sorulur.
// Bu test o katmanların KODDAN ve BASELINE ŞEMADAN sessizce düşmesini yakalar
// (webhook `serve` içinde inline; canlı para yolunu test için refactor etmek
// Apple dondurması + risk yüzünden bilinçli olarak yapılmadı — 05.09 kararı).
// Canlı prova 05.09: aynı (operation_id, order_id) ile 2. insert 0 satır (rollback'li).
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'

const ROOT = new URL('../../', import.meta.url)
const src = await Deno.readTextFile(new URL('supabase/functions/tochka-webhook/index.ts', ROOT))
const baseline = await Deno.readTextFile(new URL('supabase/schema/public_baseline.sql', ROOT))

/** Verilen imzadan başlayan SQL şablon literalinin sonuna (`,) kadar olan metin. */
function sqlStatementsStartingWith(needle: string): string[] {
  const out: string[] = []
  let from = 0
  for (;;) {
    const i = src.indexOf(needle, from)
    if (i < 0) break
    const end = src.indexOf('`,', i)
    out.push(src.slice(i, end < 0 ? src.length : end))
    from = i + needle.length
  }
  return out
}

Deno.test('şema: payments (operation_id, order_id) UNIQUE kısıtı baseline\'da', () => {
  assert(
    /CONSTRAINT payments_operation_order_key UNIQUE \(operation_id, order_id\)/.test(baseline),
    'payments_operation_order_key baseline\'dan düşmüş — webhook idempotensisi DB katmanını kaybeder',
  )
})

Deno.test('her payments INSERT (operation_id, order_id) çakışmasında sessizce düşer', () => {
  const inserts = sqlStatementsStartingWith('insert into payments')
  assertEquals(inserts.length, 2, 'F2 renewal + F1 dış-link olmak üzere 2 insert beklenir')
  for (const stmt of inserts) {
    assert(
      stmt.includes('on conflict (operation_id, order_id) do nothing'),
      'on conflict koruması olmayan payments insert: ' + stmt.slice(0, 80),
    )
  }
})

Deno.test('pending→paid sahiplenme yalnız pending satırda (ikinci teslim 0 satır döner)', () => {
  // F2: bekleyen bağlama satırı
  assert(src.includes("where operation_id = $1 and order_id = '' and status = 'pending'"))
  // F1: tek seferlik ödeme
  assert(src.includes("where operation_id = $1 and status = 'pending'"))
})

Deno.test('F2: premium uzatma yalnız kayıt gerçekten uygulandıysa (applied) — yarışı kaybeden uzatmaz', () => {
  const guard = src.indexOf('if (!applied) continue')
  const grant = src.indexOf('await grantPeriod(db, sub.user_id, sub.id, periodDays)')
  assert(guard > 0 && grant > 0, 'applied bekçisi veya grantPeriod çağrısı yok')
  assert(guard < grant, 'grantPeriod applied bekçisinden ÖNCE çağrılıyor')
  assertEquals(src.split('await grantPeriod(').length - 1, 1, 'grantPeriod tek yerden çağrılmalı')
})

Deno.test('F1: zaten işlenmiş operasyonda ikinci teslim aktivasyon yapmaz', () => {
  const check = src.indexOf('select 1 from payments where operation_id = $1')
  assert(check > 0, 'mevcut kayıt kontrolü yok')
  const after = src.slice(check, check + 400)
  assert(/return new Response\('ok'\)/.test(after), 'mevcut kayıtta erken çıkış yok')
})

Deno.test('gövdeye güvenilmez: bankadan doğrulama DB\'ye dokunmadan önce, APPROVED değilse çıkış', () => {
  const verify = src.indexOf('/acquiring/v1.0/payments/')
  const dbOpen = src.indexOf('new Client(DB_URL)')
  assert(verify > 0 && dbOpen > 0 && verify < dbOpen, 'banka doğrulaması DB bağlantısından önce olmalı')
  assert(src.includes("op?.status !== 'APPROVED'"), 'APPROVED dışı durumda erken çıkış yok')
})

Deno.test('banka ulaşılamazsa (5xx) 500 dönülür — Точка tekrar dener, kayıt kaybolmaz', () => {
  assert(/verifyRes\.status >= 500[\s\S]{0,250}status: 500/.test(src))
})
