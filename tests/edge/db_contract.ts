// DB SÖZLEŞMESİ — prod CHECK kısıtlarının kod tarafındaki tek kaynağı.
// 01.08.2026 prod'dan üretildi. Yeniden üretmek için:
//   ssh timeweb "docker exec supabase-db psql -U postgres -At -c \"select
//     conrelid::regclass || '|' || pg_get_constraintdef(oid) from pg_constraint
//     where contype='c' and pg_get_constraintdef(oid) like '%status%'\""
// NEDEN VAR: 31.07 iade akışında kod 'canceled' yazdı, DB yalnız 'cancelled'
// kabul ediyordu — gerçek iadede patlayacaktı. Bu sınıf artık CI'da yakalanır.

export const PAYMENT_STATUSES = new Set([
  'pending', 'paid', 'refunded', 'failed', 'expired',
])

export const SUBSCRIPTION_STATUSES = new Set([
  'pending_binding', 'active', 'cancelled', 'past_due', 'expired',
])

export const APPLICATION_STATUSES = new Set([
  'pending', 'selected', 'accepted', 'rejected', 'expired', 'withdrawn',
])

export const INVITATION_STATUSES = new Set([
  'active', 'selecting', 'closed', 'cancelled', 'matched',
])

export const MEETING_STATUSES = new Set(['scheduled', 'happened', 'no_show'])

// users.subscription_status — enum kısıtı yok ama kodun kullandığı değerler
export const USER_SUBSCRIPTION_STATUSES = new Set(['free', 'active'])

// selfie_status — kod yüzeylerinde geçen değerler
export const SELFIE_STATUSES = new Set(['none', 'pending', 'approved', 'rejected'])

/** Edge-fonksiyon kaynaklarında geçen herhangi bir status literalinin
 *  üyeliğini test etmek için birleşik küme. Tablolar arası karışıklığı
 *  yakalamaz (v1 sınırı) ama yazım hatası / bilinmeyen değer sınıfını yakalar. */
export const ALL_KNOWN_STATUSES = new Set([
  ...PAYMENT_STATUSES, ...SUBSCRIPTION_STATUSES, ...APPLICATION_STATUSES,
  ...INVITATION_STATUSES, ...MEETING_STATUSES, ...USER_SUBSCRIPTION_STATUSES,
  ...SELFIE_STATUSES,
])
