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

    test('accepted + aktif ilan → GÖRÜNÜR (yeşil «Принята», 22.08 kuralı)', () {
      expect(
        isMyApplicationCardVisible(
            applicationStatus: 'accepted', invitationStatus: 'active'),
        isTrue,
      );
    });

    test('accepted + süre dolmuş (selecting) → GÖRÜNMEZ — pencereyi beklemez '
        '(22.08 Mustafa: Natalia vakası)', () {
      for (final s in ['accepted', 'selected']) {
        expect(
          isMyApplicationCardVisible(
              applicationStatus: s, invitationStatus: 'selecting'),
          isFalse,
          reason: '$s + selecting düşmeli',
        );
      }
    });

    test('selecting penceresi pending/rejected için canlı sayılır', () {
      for (final s in ['pending', 'rejected']) {
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

  group('compareMyApplicationCards — pano sırası (Mustafa 16.08)', () {
    final t1 = DateTime.utc(2026, 8, 16, 10);
    final t2 = DateTime.utc(2026, 8, 16, 12); // daha yeni

    test('Kabul her zaman Bekliyor\'un önünde (tarihi eski olsa bile)', () {
      expect(
        compareMyApplicationCards(
            statusA: 'accepted', createdA: t1, statusB: 'pending', createdB: t2),
        lessThan(0),
      );
    });

    test('ЗАВЕРШЕНО (rejected) her zaman en sonda', () {
      expect(
        compareMyApplicationCards(
            statusA: 'rejected', createdA: t2, statusB: 'pending', createdB: t1),
        greaterThan(0),
      );
    });

    test('aynı grupta yeni başvuru önde (created_at DESC)', () {
      expect(
        compareMyApplicationCards(
            statusA: 'pending', createdA: t2, statusB: 'pending', createdB: t1),
        lessThan(0),
      );
    });

    test('created_at null olan grup içinde en sona düşer', () {
      expect(
        compareMyApplicationCards(
            statusA: 'pending', createdA: null, statusB: 'pending', createdB: t1),
        greaterThan(0),
      );
    });
  });
}
