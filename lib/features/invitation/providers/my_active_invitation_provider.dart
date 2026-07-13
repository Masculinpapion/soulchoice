import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Kullanıcının TÜM aktif kartları (davet + istek — tür başına 1'er tane
// olabilir). Eski sürüm limit(1) ile tek kart varsayıyordu; istek özelliği
// gelince profildeki bölüm ikinci kartı gösteremiyordu.
final myActiveInvitationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return const [];

  final rows = await Supabase.instance.client
      .from('invitations')
      .select(
          'id, category, venue_name, title, expires_at, status, flow_type, city_id, '
          'city:cities(name, name_ru, name_tr, name_en), '
          'owner:users!owner_id(id, name, age, photos:user_photos(url, is_primary, is_selfie, order_index))')
      .eq('owner_id', uid)
      .eq('status', 'active')
      .gt('expires_at', DateTime.now().toUtc().toIso8601String())
      .order('created_at', ascending: false);

  if (rows.isEmpty) return const [];
  final invs = rows.map((r) => Map<String, dynamic>.from(r)).toList();

  final ids = invs.map((i) => i['id'] as String).toList();
  final apps = await Supabase.instance.client
      .from('applications')
      .select('id, invitation_id')
      .inFilter('invitation_id', ids);
  final counts = <String, int>{};
  for (final a in apps as List) {
    final invId = (a as Map)['invitation_id'] as String;
    counts[invId] = (counts[invId] ?? 0) + 1;
  }

  for (final inv in invs) {
    inv['application_count'] = counts[inv['id'] as String] ?? 0;

    final ownerRow = inv['owner'] as Map<String, dynamic>?;
    final photos = (ownerRow?['photos'] as List<dynamic>?) ?? const [];
    final nonSelfie = photos
        .cast<Map<String, dynamic>>()
        .where((p) => (p['is_selfie'] as bool? ?? false) == false)
        .toList()
      ..sort((a, b) {
        final aP = a['is_primary'] as bool? ?? false;
        final bP = b['is_primary'] as bool? ?? false;
        if (aP != bP) return aP ? -1 : 1;
        final aO = a['order_index'] as int? ?? 999;
        final bO = b['order_index'] as int? ?? 999;
        return aO.compareTo(bO);
      });
    inv['owner_photo_url'] =
        nonSelfie.isNotEmpty ? nonSelfie.first['url'] as String? : null;
  }

  return invs;
});
