import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final applicantsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, invitationId) async {
  final data = await Supabase.instance.client
      .from('applications')
      .select('id, status, created_at, applicant:users(id, name, age, gender, verified, bio, interests, photos:user_photos(url, is_primary))')
      .eq('invitation_id', invitationId)
      .eq('status', 'pending')
      .order('created_at');
  return List<Map<String, dynamic>>.from(data as List);
});
