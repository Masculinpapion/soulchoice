import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final invitationDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final data = await Supabase.instance.client
      .from('invitations')
      .select('*, place:places(website), owner:users(id, name, age, gender, subscription_status, selfie_status, city_id, city:cities(name, name_ru, name_tr, name_en))')
      .eq('id', id)
      .maybeSingle();
  if (data == null) return null;
  final ownerId = data['owner_id'] as String?;
  if (ownerId != null) {
    final rawPhotos = await Supabase.instance.client
        .from('user_photos')
        .select()
        .eq('user_id', ownerId);
    final allPhotos = List<Map<String, dynamic>>.from(rawPhotos as List);
    print('[SC_PHOTOS] Total fetched: ${allPhotos.length} for owner $ownerId');
    for (final p in allPhotos) {
      print('[SC_PHOTOS] is_selfie=${p["is_selfie"]} order=${p["order_index"]} url=${(p["url"] as String?)?.split("/").last}');
    }
    final nonSelfies = allPhotos
        .where((p) => p['is_selfie'] != true)
        .toList()
      ..sort((a, b) => (a['order_index'] as int? ?? 99)
          .compareTo(b['order_index'] as int? ?? 99));
    print('[SC_PHOTOS] Non-selfie count: ${nonSelfies.length}');
    final newData = Map<String, dynamic>.from(data);
    newData['owner_photos'] = nonSelfies;
    return newData;
  }
  return data;
});

final myApplicationProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, invitationId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  return Supabase.instance.client
      .from('applications')
      .select('id, status')
      .eq('invitation_id', invitationId)
      .eq('applicant_id', uid)
      .neq('status', 'withdrawn')
      .maybeSingle();
});

final applicationCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, invitationId) async {
  final data = await Supabase.instance.client
      .from('applications')
      .select('id')
      .eq('invitation_id', invitationId)
      .eq('status', 'pending');
  return (data as List).length;
});

