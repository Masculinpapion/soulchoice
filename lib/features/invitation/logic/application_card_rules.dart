/// Profil "Başvurularım" kart yaşam döngüsü kuralları — SAF mantık.
/// TEK KAYNAK: docs/product-logic.md §4 NİHAİ KARAR (Mustafa 11.08 gece):
/// pano ANLIK DURUM gösterir; kart ömrü = ilan ömrü. İlan canlıyken
/// (active/selecting) pending=sarı Bekliyor, accepted=yeşil, rejected=gri
/// ЗАВЕРШЕНО; ilan kapanınca kart durumu ne olursa olsun düşer (kabul dahil).
/// withdrawn/expired hiç görünmez.
///
/// Bu dosya Supabase'e dokunmaz — provider/ekran buradan çağırır, testler
/// (test/logic/application_card_rules_test.dart) doğrudan burayı test eder.
/// Kural değişecekse ÖNCE product-logic.md, sonra burası, sonra test.
library;

/// Kart panoda görünür mü? (my_applications_provider filtresinin tek kaynağı)
///
/// [invitationStatus] `null` = ilan silinmiş / embed join boş → kart düşer.
/// `closed` → kart düşer. `cancelled`/`matched` legacy'dir, hiçbir kod set
/// etmez (product-logic §11) — mevcut davranışla birebir aynı kalması için
/// yalnız `closed` elenir (davranış değişikliği YOK; sabah incelemesi notu:
/// legacy statüler canlanırsa burada karar gerekir).
bool isMyApplicationCardVisible({
  required String applicationStatus,
  required String? invitationStatus,
}) {
  // Kendi eylemi (withdrawn) ve kapalı-ilan artığı (expired) panoda yaşamaz.
  if (applicationStatus == 'withdrawn' || applicationStatus == 'expired') {
    return false;
  }
  return invitationStatus != null && invitationStatus != 'closed';
}

/// Canlı penceredeki kartın rozet türü (renk/metin eşlemesi ekranda kalır;
/// hangi statünün hangi rozete gittiği ürün kuralıdır ve burada yaşar).
enum ApplicationChipKind {
  /// Sarı "Bekliyor" — pending (ve kullanılmayan legacy `selected` dahil
  /// bilinmeyen her değer güvenli varsayılan olarak beklemeye düşer).
  pending,

  /// Yeşil "Kabul edildi".
  accepted,

  /// Gri "ЗАВЕРШЕНО/TAMAMLANDI" — rejected'ın kullanıcıya görünen yüzü;
  /// açık "reddedildin" yazmaz ama boş umudu keser (product-logic §4).
  completed,
}

ApplicationChipKind applicationChipKind(String applicationStatus) =>
    switch (applicationStatus) {
      'accepted' => ApplicationChipKind.accepted,
      'rejected' => ApplicationChipKind.completed,
      _ => ApplicationChipKind.pending,
    };

/// Panodaki kart SIRASI (Mustafa 16.08): önce yeşil Kabul (aksiyon: sohbete
/// geç), sonra sarı Bekliyor, en sonda gri ЗАВЕРШЕНО; aynı grup içinde
/// yeniden→eskiye (created_at DESC — yeniden başvuruda DB trigger'ı
/// created_at'i sıfırlar: 20260816_reapply_resets_created_at.sql).
int applicationCardSortRank(String applicationStatus) =>
    switch (applicationChipKind(applicationStatus)) {
      ApplicationChipKind.accepted => 0,
      ApplicationChipKind.pending => 1,
      ApplicationChipKind.completed => 2,
    };

/// Sıralayıcı: rank ASC, sonra createdAt DESC (null en sona).
int compareMyApplicationCards({
  required String statusA,
  required DateTime? createdA,
  required String statusB,
  required DateTime? createdB,
}) {
  final r = applicationCardSortRank(statusA).compareTo(applicationCardSortRank(statusB));
  if (r != 0) return r;
  if (createdA == null && createdB == null) return 0;
  if (createdA == null) return 1;
  if (createdB == null) return -1;
  return createdB.compareTo(createdA);
}
