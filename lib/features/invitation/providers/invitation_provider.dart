import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final invitationDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final data = await Supabase.instance.client
      .from('invitations')
      .select('*, owner:users(id, name, age, gender, verified, city_id, city:cities(name, name_ru, name_tr, name_en))')
      .eq('id', id)
      .maybeSingle();
  if (data == null) return null;
  final ownerId = data['owner_id'] as String?;
  if (ownerId != null) {
    final rawPhotos = await Supabase.instance.client
        .from('user_photos')
        .select('url, is_primary, is_selfie, order_index')
        .eq('user_id', ownerId);
    final allPhotos = List<Map<String, dynamic>>.from(rawPhotos as List);
    final nonSelfies = allPhotos
        .where((p) => p['is_selfie'] != true)
        .toList()
      ..sort((a, b) => (a['order_index'] as int? ?? 99)
          .compareTo(b['order_index'] as int? ?? 99));
    data['owner_photos'] = nonSelfies;
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
