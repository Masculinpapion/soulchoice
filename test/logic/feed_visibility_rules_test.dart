// Feed accepted-gizleme kural testleri — product-logic.md §6 (11.08):
// kabul edilmiş başvuran ilan kartını feed'de görmez; ilan diğer adaylara
// görünmeye devam eder; kendi ilanı ASLA elenmez; pending/selected/rejected
// görünürlüğü AYNEN kalır (sessizlik ilkesi).
import 'package:flutter_test/flutter_test.dart';
import 'package:soulchoice/features/feed/logic/feed_visibility_rules.dart';

Map<String, dynamic> app(String status, String applicantId) =>
    {'status': status, 'applicant': {'id': applicantId}};

void main() {
  const me = 'user-me';
  const other = 'user-other';
  const owner = 'user-owner';

  group('hideInvitationFromViewer (§6, 11.08)', () {
    test('kabul edilmiş başvuran → kart GİZLENİR', () {
      expect(
        hideInvitationFromViewer(
          applications: [app('accepted', me), app('pending', other)],
          viewerId: me,
          ownerId: owner,
        ),
        isTrue,
      );
    });

    test('BAŞKASININ kabulü benim görünürlüğümü etkilemez', () {
      expect(
        hideInvitationFromViewer(
          applications: [app('accepted', other)],
          viewerId: me,
          ownerId: owner,
        ),
        isFalse,
      );
    });

    test('pending/selected/rejected başvuran kartı GÖRMEYE DEVAM EDER '
        '(rejected gizlenmez — red sinyali sızmaz)', () {
      for (final s in ['pending', 'selected', 'rejected']) {
        expect(
          hideInvitationFromViewer(
            applications: [app(s, me)],
            viewerId: me,
            ownerId: owner,
          ),
          isFalse,
          reason: '$s başvurusu kartı gizlememeli',
        );
      }
    });

    test('kendi ilanı ASLA elenmez (kabul kaydı olsa bile)', () {
      expect(
        hideInvitationFromViewer(
          // Savunmacı senaryo: veri bozulup sahibin "kabul" kaydı görünse de
          // sahiplik gizlemeyi iptal eder.
          applications: [app('accepted', owner)],
          viewerId: owner,
          ownerId: owner,
        ),
        isFalse,
      );
    });

    test('anonim izleyici (viewerId null) hiçbir kartı kaçırmaz', () {
      expect(
        hideInvitationFromViewer(
          applications: [app('accepted', other)],
          viewerId: null,
          ownerId: owner,
        ),
        isFalse,
      );
    });

    test('başvurusuz ilan herkese görünür', () {
      expect(
        hideInvitationFromViewer(
            applications: const [], viewerId: me, ownerId: owner),
        isFalse,
      );
    });

    test('applicant embed null (silinmiş kullanıcı) patlamaz ve gizlemez', () {
      expect(
        hideInvitationFromViewer(
          applications: [
            {'status': 'accepted', 'applicant': null},
          ],
          viewerId: me,
          ownerId: owner,
        ),
        isFalse,
      );
    });
  });
}
