import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logic/application_card_rules.dart';

/// Kullanıcının kendi başvuruları — profildeki "Başvurularım" bölümü.
/// NİHAİ KURAL (Mustafa 11.08 gece): burası ANLIK DURUM PANOSU — kart ömrü
/// = ilan ömrü. İlan canlıyken (active/selecting): Bekliyor/Kabul, reddedilen
/// ise gri ЗАВЕРШЕНО (boş umut yerine sıradakine geçsin). İlan kapanınca kart
/// durumu ne olursa olsun düşer (kabul dahil — ilişki Mesajlar'da).
/// withdrawn (kendi eylemi) ve expired (zaten kapalı ilanda) gizli.
final myApplicationsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await Supabase.instance.client
      .from('applications')
      .select('id, status, created_at, invitation_id, '
          'invitation:invitations(id, title, category, status, '
          'owner:users!owner_id(name))')
      .eq('applicant_id', uid)
      .neq('status', 'withdrawn')
      .neq('status', 'expired')
      .order('created_at', ascending: false)
      .limit(20);
  return (rows as List)
      .cast<Map<String, dynamic>>()
      // İlan kapandıysa/silindiyse kart düşer — pano yalnız canlı süreci
      // gösterir. Kural tek kaynakta: application_card_rules.dart (test edilir).
      .where((a) {
        final inv = a['invitation'] as Map<String, dynamic>?;
        return isMyApplicationCardVisible(
          applicationStatus: a['status'] as String? ?? 'pending',
          invitationStatus: inv?['status'] as String?,
        );
      })
      .toList();
});
