import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kullanıcının kendi başvuruları — profildeki "Başvurularım" bölümü.
/// Amaç: başvuranın akıbeti TAKİP EDEBİLMESİ (15.07 yolculuk bulgusu 🟠2).
/// 11.08 REVİZE (Mustafa): olumsuz sonuç artık GİZLENMEZ — kart kalır, rozet
/// nötr "ЗАВЕРШЕНО" olur ("seçtiklerimiz nereye kayboluyor?" sorunu).
/// Kart ömrü = ilan ömrü: cron kapalı ilanı 30 gün sonra siler (CASCADE),
/// kart da o zaman sessizce düşer. withdrawn (kullanıcının kendi eylemi)
/// gizli kalır.
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
      .order('created_at', ascending: false)
      .limit(20);
  return (rows as List).cast<Map<String, dynamic>>().toList();
});
