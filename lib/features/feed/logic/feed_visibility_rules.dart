/// Feed kart görünürlüğü — SAF mantık (Supabase'e dokunmaz).
/// TEK KAYNAK: docs/product-logic.md §6 (11.08, Mustafa bulgusu):
/// KABUL edilmiş başvuran ilan kartını feed'de artık görmez ("Хочу прийти"
/// onun için ölü mekanikti; ilişki Mesajlar'da). İlan diğer adaylara
/// görünmeye devam eder; pending/selected/rejected görünürlüğü AYNEN kalır
/// (rejected'ı gizlemek sessizlik ilkesini deler). Kendi ilanı ASLA elenmez.
library;

/// İlan kartı bu izleyici için feed'den gizlenmeli mi?
///
/// [applications] ilan satırındaki embed başvuru listesi; her öğe en az
/// `{'status': ..., 'applicant': {'id': ...}}` şeklindedir (invitations_provider
/// select'iyle aynı biçim). Yalnız `accepted` + izleyici-id eşleşmesi gizler.
bool hideInvitationFromViewer({
  required List<Map<String, dynamic>> applications,
  required String? viewerId,
  required String? ownerId,
}) {
  if (viewerId == null) return false; // anonim izleyici her kartı görür
  // Kendi ilanı her zaman görünür (sahibi kendine başvuramaz — DB zorlar —
  // ama kural burada da açıkça durur: sahiplik gizlemeyi daima iptal eder).
  if (ownerId != null && ownerId == viewerId) return false;
  return applications.any((a) =>
      a['status'] == 'accepted' &&
      (a['applicant'] as Map<String, dynamic>?)?['id'] == viewerId);
}
