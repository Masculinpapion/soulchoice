// Kart yaşam döngüsü kural testleri — product-logic.md §4 NİHAİ KARAR
// (Mustafa 11.08 gece): profil panosu = ANLIK; kart ömrü = ilan ömrü.
// 11-12.08 hata sınıfı: durum geçişi sonrası ekranın yanlış kart göstermesi.
// Kural değişirse ÖNCE product-logic.md, sonra application_card_rules.dart,
// sonra bu test güncellenir.
import 'package:flutter_test/flutter_test.dart';
import 'package:soulchoice/features/invitation/logic/application_card_rules.dart';

void main() {
  group('isMyApplicationCardVisible — kart ömrü = ilan ömrü (§4)', () {
    test('pending + aktif ilan → GÖRÜNÜR (sarı Bekliyor)', () {
      expect(
        isMyApplicationCardVisible(
            applicationStatus: 'pending', invitationStatus: 'active'),
        isTrue,
      );
    });

    test('rejected + aktif ilan → GÖRÜNÜR (gri ЗАВЕРШЕНО — gizlenmez, '
        'boş umudu keser ama red sinyalini sızdırmaz)', () {
      expect(
        isMyApplicationCardVisible(
            applicationStatus: 'rejected', invitationStatus: 'active'),
        isTrue,
      );
    });

    test('accepted + aktif ilan → GÖRÜNÜR (yeşil)', () {
      expect(
        isMyApplicationCardVisible(
            applicationStatus: 'accepted', invitationStatus: 'active'),
        isTrue,
      );
    });

    test('selecting penceresi canlı sayılır — pending/rejected/accepted görünür',
        () {
      for (final s in ['pending', 'rejected', 'accepted']) {
        expect(
          isMyApplicationCardVisible(
              applicationStatus: s, invitationStatus: 'selecting'),
          isTrue,
          reason: '$s + selecting görünür olmalı',
        );
      }
    });

    test('HERHANGİ durum + closed ilan → GÖRÜNMEZ (kabul dahil düşer)', () {
      for (final s in [
        'pending', 'selected', 'accepted', 'rejected', 'expired', 'withdrawn',
      ]) {
        expect(
          isMyApplicationCardVisible(
              applicationStatus: s, invitationStatus: 'closed'),
          isFalse,
          reason: '$s + closed kart düşmeli',
        );
      }
    });

    test('ilan silinmiş (embed join null) → GÖRÜNMEZ', () {
      expect(
        isMyApplicationCardVisible(
            applicationStatus: 'accepted', invitationStatus: null),
        isFalse,
      );
    });

    test('withdrawn/expired → ilan durumu ne olursa olsun GÖRÜNMEZ', () {
      for (final inv in ['active', 'selecting', 'closed', null]) {
        expect(
          isMyApplicationCardVisible(
              applicationStatus: 'withdrawn', invitationStatus: inv),
          isFalse,
          reason: 'withdrawn + $inv gizli olmalı',
        );
        expect(
          isMyApplicationCardVisible(
              applicationStatus: 'expired', invitationStatus: inv),
          isFalse,
          reason: 'expired + $inv gizli olmalı',
        );
      }
    });
  });

  group('applicationChipKind — canlı penceredeki rozet eşlemesi (§4)', () {
    test('accepted → yeşil kabul rozeti', () {
      expect(applicationChipKind('accepted'), ApplicationChipKind.accepted);
    });

    test('rejected → gri ЗАВЕРШЕНО (açık "reddedildin" YOK)', () {
      expect(applicationChipKind('rejected'), ApplicationChipKind.completed);
    });

    test('pending ve bilinmeyen/legacy değerler güvenli varsayılan: Bekliyor',
        () {
      expect(applicationChipKind('pending'), ApplicationChipKind.pending);
      expect(applicationChipKind('selected'), ApplicationChipKind.pending);
    });
  });
}
