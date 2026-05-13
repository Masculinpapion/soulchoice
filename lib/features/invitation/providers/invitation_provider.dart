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
    final photos = await Supabase.instance.client
        .from('user_photos')
        .select('url, is_primary, is_selfie, order_index')
        .eq('user_id', ownerId)
        .neq('is_selfie', true)
        .order('order_index');
    data['owner_photos'] = photos;
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
