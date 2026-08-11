// SÖZLEŞME TESTİ: durum-geçişi kuralları — 11-12.08 hata sınıfı (kart yaşam
// döngüsü / RLS görünürlük / geri-çekme zinciri) için repo-taraflı kilit.
//
// NE TEST EDER: supabase/migrations/ içindeki KANONİK (dosya adına göre en
// yeni) tanımların ürün kurallarını içerdiğini — yani birinin migration'ı
// düzenleyip/yeni migration ekleyip şu garantileri sessizce düşürmesini:
//   1) rejected/expired → withdrawn engeli (trg_block_withdraw_after_decision)
//   2) cleanup_closed_invitations: YALNIZ closed + match'siz ilanı siler
//   3) invitations_select RLS: başvuranı olan ilan durumdan bağımsız görünür
//      (has_application_to), sahibi hep görür, yabancı yalnız active görür
//   4) enforce_application_rules: pending'e dönüş YALNIZ withdrawn'dan ve
//      YALNIZ açık (active + süresi geçmemiş) ilanda
//   5) db_contract.ts geçiş matrisi ↔ status kümesi tutarlılığı
//
// v1 SINIRI (bilinçli): canlı prod davranışını DEĞİL repo'daki kanonik SQL'i
// doğrular — status_literals_test ile aynı sınıf. Repo↔prod drift'i mevcut
// disiplinle kapanır (db_contract.ts başlığındaki "prod'dan yeniden üret"
// komutu + platform denetimi dersi: policy'leri canlıdan doğrula). Gerçek
// INSERT/UPDATE davranış testi için taslak: tests/db/state_transitions.draft.sql
// (tek kullanımlık klon DB ister, CI'da koşmaz — başlığına bak).
import { assert } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  APPLICATION_STATUSES,
  CLIENT_APPLICATION_TRANSITIONS,
} from './db_contract.ts'

const MIG_DIR = new URL('../../supabase/migrations/', import.meta.url)

/** Tüm migration'ları dosya adı sırasıyla (kronolojik) okur. */
async function loadMigrations(): Promise<Array<{ name: string; sql: string }>> {
  const names: string[] = []
  for await (const e of Deno.readDir(MIG_DIR)) {
    if (e.isFile && e.name.endsWith('.sql')) names.push(e.name)
  }
  names.sort()
  const out = []
  for (const name of names) {
    out.push({
      name,
      sql: await Deno.readTextFile(new URL(name, MIG_DIR)),
    })
  }
  return out
}

/** Normalize: yorum satırlarını at, boşlukları tekle, küçük harfe indir —
 *  assert'ler biçimden bağımsız kalsın. */
function norm(sql: string): string {
  return sql
    .split('\n')
    .filter((l) => !l.trimStart().startsWith('--'))
    .join(' ')
    .replace(/\s+/g, ' ')
    .toLowerCase()
}

/** `marker` içeren EN YENİ migration'ı döndürür (kanonik tanım). */
function latestDefining(
  migs: Array<{ name: string; sql: string }>,
  marker: RegExp,
): { name: string; norm: string } {
  const hits = migs.filter((m) => marker.test(norm(m.sql)))
  assert(hits.length > 0, `hiçbir migration şunu tanımlamıyor: ${marker}`)
  const last = hits[hits.length - 1]
  return { name: last.name, norm: norm(last.sql) }
}

const migs = await loadMigrations()

Deno.test('1) rejected/expired→withdrawn engeli kanonik SQL\'de duruyor', () => {
  const def = latestDefining(
    migs,
    /create or replace function public\.block_withdraw_after_decision/,
  )
  assert(
    /if new\.status = 'withdrawn' and old\.status in \('rejected', ?'expired'\) then raise exception 'invalid_status_transition'/
      .test(def.norm),
    `${def.name}: rejected/expired→withdrawn engeli INVALID_STATUS_TRANSITION ` +
      'fırlatmıyor — 11.08 kararı (reddedilen kendini yeniden sokamaz) düşmüş',
  )
  assert(
    /create trigger trg_block_withdraw_after_decision before update on public\.applications/
      .test(def.norm),
    `${def.name}: trigger BEFORE UPDATE olarak applications'a bağlı değil`,
  )
  // service_role muafiyeti bilinçli — cron/ops bozulmasın
  assert(
    /service_role/.test(def.norm),
    `${def.name}: service_role muafiyeti kaybolmuş (cron/ops kırılır)`,
  )
})

Deno.test('2) cleanup_closed_invitations: YALNIZ closed + match\'siz siler', () => {
  const def = latestDefining(
    migs,
    /create or replace function public\.cleanup_closed_invitations/,
  )
  // Tek delete ifadesinde İKİ koşul birden: status='closed' VE matches yok.
  const del = def.norm.match(/delete from public\.invitations[^;]*/)
  assert(del !== null, `${def.name}: delete ifadesi bulunamadı`)
  assert(
    /i\.status = 'closed'/.test(del![0]),
    `${def.name}: delete closed dışı ilanları da kapsıyor olabilir — ` +
      "status='closed' koşulu delete içinde yok",
  )
  assert(
    /not exists \( ?select 1 from public\.matches m where m\.invitation_id = i\.id ?\)/
      .test(del![0]),
    `${def.name}: match'li ilan koruması düşmüş — sohbet başlığı verisi ` +
      'silinir (product-logic §4: match\'i VARSA silinmez)',
  )
  // 11.08 gece iptal edilen 30 gün bekletme geri sızmasın (kanonik = anında)
  assert(
    !/closed_at|interval '30 day/.test(del![0]),
    `${def.name}: 30 gün saklama koşulu delete'e geri gelmiş — ` +
      '11.08 nihai karar: pano anlık, saklama YOK',
  )
})

Deno.test('3) invitations_select RLS: başvuran kapalı ilanı görür, yabancı görmez', () => {
  const def = latestDefining(migs, /alter policy invitations_select/)
  const pol = def.norm.match(/alter policy invitations_select[^;]*/)![0]
  assert(
    /public\.has_application_to\(id\)/.test(pol),
    `${def.name}: has_application_to istisnası düşmüş — kabul edilen ` +
      'başvuranın profil kartı ilan kapanınca boşalır (11.08 vakası)',
  )
  assert(
    /owner_id = auth\.uid\(\)/.test(pol),
    `${def.name}: sahibin kendi ilanını görme koşulu düşmüş`,
  )
  assert(
    /status = 'active'/.test(pol),
    `${def.name}: yabancıya yalnız-active koşulu düşmüş — kapalı ilanlar ` +
      'herkese sızar',
  )
  // İstisna fonksiyonu: yalnız KENDİ başvurusu sayılır + RLS özyinelemesini
  // security definer kırar (migration başlık notu)
  const fn = latestDefining(
    migs,
    /create or replace function public\.has_application_to/,
  )
  assert(
    /security definer/.test(fn.norm) &&
      /applicant_id = auth\.uid\(\)/.test(fn.norm),
    `${fn.name}: has_application_to security definer + auth.uid() ` +
      'kısıtından sapmış (yabancı başvurusu üzerinden görünürlük sızar)',
  )
})

Deno.test('4) enforce_application_rules: pending\'e dönüş yalnız withdrawn\'dan + açık ilanda', () => {
  const def = latestDefining(
    migs,
    /create or replace function public\.enforce_application_rules/,
  )
  assert(
    /if old\.status <> 'withdrawn' then raise exception 'invalid_status_transition'/
      .test(def.norm),
    `${def.name}: pending'e dönüşün withdrawn dışı kaynağı engellenmiyor`,
  )
  // Yeniden-başvuru da ilk başvuru kurallarına tabi: ilan açık + süresi var
  assert(
    /i\.status = 'active' and i\.expires_at > now\(\)/.test(def.norm),
    `${def.name}: withdrawn→pending açık-ilan şartı (active + süresi ` +
      'geçmemiş) düşmüş — kapalı ilana yeniden başvuru açılır',
  )
  assert(
    /raise exception 'application_must_start_pending'/.test(def.norm),
    `${def.name}: doğrudan accepted INSERT engeli düşmüş`,
  )
})

Deno.test('5) geçiş matrisi ↔ status kümesi tutarlı', () => {
  // Matristeki her anahtar/hedef gerçek bir application status'u olmalı
  for (const [from, tos] of Object.entries(CLIENT_APPLICATION_TRANSITIONS)) {
    assert(APPLICATION_STATUSES.has(from), `matris anahtarı tanınmıyor: ${from}`)
    for (const to of tos) {
      assert(APPLICATION_STATUSES.has(to), `matris hedefi tanınmıyor: ${from}→${to}`)
    }
  }
  // Her status matriste açıkça kararlaştırılmış olmalı (yeni status eklenince
  // bu test kırmızı yanar → önce ürün kararı, sonra matris)
  for (const s of APPLICATION_STATUSES) {
    assert(
      s in CLIENT_APPLICATION_TRANSITIONS,
      `yeni/karar verilmemiş status matriste yok: ${s}`,
    )
  }
  // 11.08 kararlarının matristeki izdüşümü
  assert(
    !CLIENT_APPLICATION_TRANSITIONS['rejected'].includes('withdrawn') &&
      !CLIENT_APPLICATION_TRANSITIONS['expired'].includes('withdrawn'),
    'matris rejected/expired→withdrawn izni veriyor — 11.08 kararına aykırı',
  )
  assert(
    CLIENT_APPLICATION_TRANSITIONS['withdrawn'].includes('pending'),
    'matris withdrawn→pending yeniden-başvurusunu kaybetmiş (24.07 kararı)',
  )
})
