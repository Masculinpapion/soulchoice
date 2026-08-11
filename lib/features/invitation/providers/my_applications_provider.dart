import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kullanıcının kendi başvuruları — profildeki "Başvurularım" bölümü.
/// NİHAİ KURAL (Mustafa 11.08 gece): burası ANLIK DURUM PANOSU — süreç
/// canlıyken (ilan active/selecting) Bekliyor/Kabul görünür; ilan kapanınca
/// kart DURUMU NE OLURSA OLSUN düşer (kabul dahil — ilişki Mesajlar'da).
/// rejected/expired/withdrawn her zaman gizli (sessizlik ilkesi).
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
      .neq('status', 'rejected')
      .neq('status', 'expired')
      .order('created_at', ascending: false)
      .limit(20);
  return (rows as List)
      .cast<Map<String, dynamic>>()
      // İlan kapandıysa/silindiyse kart düşer — pano yalnız canlı süreci gösterir
      .where((a) {
        final inv = a['invitation'] as Map<String, dynamic>?;
        return inv != null && inv['status'] != 'closed';
      })
      .toList();
});
