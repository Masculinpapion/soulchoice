// SÖZLEŞME TESTİ: edge fonksiyon kaynaklarında geçen her status literali
// prod CHECK kısıtlarından üretilen sözleşmede (db_contract.ts) olmalı.
// 31.07 'canceled' (tek L) hatasını bu sınıf test yakalar: DB yalnız
// 'cancelled' kabul ederken kodda bilinmeyen bir değer yazılamaz.
// v1 sınırı: tablolar arası karışıklığı (payments değeri subscriptions'ta)
// yakalamaz; yazım hatası / bilinmeyen değer sınıfını yakalar.
import { assert } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { ALL_KNOWN_STATUSES } from './db_contract.ts'

const FN_DIR = new URL('../../supabase/functions/', import.meta.url)

// status = 'x' | status <> 'x' | status: 'x' | status=eq.x | status in ('a','b')
const PATTERNS = [
  /\bstatus\s*(?:=|<>|!==|===|:)\s*'([a-z_]+)'/g,
  /\bstatus=eq\.([a-z_]+)/g,
]
const IN_LIST = /\bstatus\s+in\s*\(([^)]*)\)/gi
const QUOTED = /'([a-z_]+)'/g

async function collectSources(dir: URL): Promise<Map<string, string>> {
  const out = new Map<string, string>()
  for await (const e of Deno.readDir(dir)) {
    const child = new URL(e.isDirectory ? `${e.name}/` : e.name, dir)
    if (e.isDirectory) {
      for (const [k, v] of await collectSources(child)) out.set(k, v)
    } else if (e.name.endsWith('.ts')) {
      out.set(child.pathname, await Deno.readTextFile(child))
    }
  }
  return out
}

Deno.test('edge fonksiyonlardaki tüm status literalleri DB sözleşmesinde', async () => {
  const sources = await collectSources(FN_DIR)
  assert(sources.size > 10, `beklenmedik az kaynak dosya: ${sources.size}`)
  const violations: string[] = []
  for (const [path, src] of sources) {
    const found = new Set<string>()
    for (const re of PATTERNS) {
      for (const m of src.matchAll(re)) found.add(m[1])
    }
    for (const m of src.matchAll(IN_LIST)) {
      for (const q of m[1].matchAll(QUOTED)) found.add(q[1])
    }
    for (const lit of found) {
      if (!ALL_KNOWN_STATUSES.has(lit)) {
        violations.push(`${path.split('/supabase/')[1]}: '${lit}'`)
      }
    }
  }
  assert(
    violations.length === 0,
    'DB sözleşmesinde olmayan status literalleri (yazım hatası? yeni değer? ' +
      'yeniyse önce DB kısıtı + tests/edge/db_contract.ts güncellenir):\n' +
      violations.join('\n'),
  )
})
