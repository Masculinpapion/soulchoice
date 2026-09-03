// 03.09.2026 — Bildirim tipi sözleşmesi (kalite teşhisi K1: aynı enum 6 migration + 4 Dart dosyasında).
// 02.09 vakası: profile-nudge.sh 'profile_incomplete' yazdı, notifications_type_check tanımıyordu,
// 3 cron koşusu sessizce reddedildi. Bu test, notifications tablosuna YAZAN her kaynağın kullandığı
// tipin prod baseline'daki CHECK listesinde olduğunu doğrular.
// Kaynak: supabase/schema/public_baseline.sql (prod pg_dump -s, gece drift job'ı ile taze tutulur).
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'

const baseline = await Deno.readTextFile(new URL('../../supabase/schema/public_baseline.sql', import.meta.url))

function checkList(): Set<string> {
  const m = baseline.match(/CONSTRAINT notifications_type_check CHECK \(\(type = ANY \(ARRAY\[([^\]]+)\]\)\)\)/)
  if (!m) throw new Error('notifications_type_check baseline\'da bulunamadı')
  return new Set([...m[1].matchAll(/'([a-z_]+)'::text/g)].map((x) => x[1]))
}

// "insert into [public.]notifications (cols) values (vals)" → type sütunundaki literal
function insertedTypes(sql: string): string[] {
  const out: string[] = []
  const re = /insert\s+into\s+(?:public\.)?notifications\s*\(([^)]*)\)\s*(?:values|select)\s*\(?([\s\S]*?)(?:;|\bon\s+conflict\b|\bfrom\b)/gi
  for (const m of sql.matchAll(re)) {
    const cols = m[1].split(',').map((c) => c.trim().toLowerCase())
    const idx = cols.indexOf('type')
    if (idx < 0) continue
    const vals: string[] = []
    let depth = 0, cur = ''
    for (const ch of m[2]) {
      if (ch === '(') depth++
      if (ch === ')') depth--
      if (ch === ',' && depth === 0) { vals.push(cur); cur = '' } else cur += ch
    }
    vals.push(cur)
    const lit = vals[idx]?.match(/'([a-z_]+)'/)
    if (lit) out.push(lit[1])
  }
  return out
}

Deno.test('notifications tablosuna yazan her SQL fonksiyonu CHECK listesindeki tipi kullanır', () => {
  const allowed = checkList()
  assert(allowed.size >= 12, 'CHECK listesi beklenenden kısa: ' + [...allowed].join(','))
  const used = insertedTypes(baseline)
  assert(used.length >= 5, 'baseline içinde notifications insert bulunamadı (regex kırıldı mı?)')
  const bad = used.filter((t) => !allowed.has(t))
  assertEquals(bad, [], 'CHECK dışı tip yazan SQL var: ' + bad.join(','))
})

Deno.test('ops/*.sh scriptleri CHECK listesindeki tipleri kullanır (02.09 profile_incomplete vakası)', async () => {
  const allowed = checkList()
  const dir = new URL('../../ops/', import.meta.url)
  const bad: string[] = []
  for await (const e of Deno.readDir(dir)) {
    if (!e.name.endsWith('.sh')) continue
    const src = await Deno.readTextFile(new URL(e.name, dir))
    for (const t of insertedTypes(src)) if (!allowed.has(t)) bad.push(`${e.name}:${t}`)
  }
  assertEquals(bad, [], 'CHECK dışı tip yazan script: ' + bad.join(','))
})

Deno.test('Dart bildirim ekranı CHECK listesindeki her tipi tanır (ham tip gösterimi yok)', async () => {
  const allowed = checkList()
  const screen = await Deno.readTextFile(new URL('../../lib/features/notifications/screens/notifications_screen.dart', import.meta.url))
  const handled = new Set([...screen.matchAll(/case '([a-z_]+)'/g)].map((x) => x[1]))
  const missing = [...allowed].filter((t) => !handled.has(t))
  assertEquals(missing, [], 'Ekranın switch\'inde olmayan DB tipi: ' + missing.join(','))
})
