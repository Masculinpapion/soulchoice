import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  return Supabase.instance.client
      .from('users')
      .select('*, city:cities(name, country)')
      .eq('id', userId)
      .maybeSingle();
});

final userPhotosProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final data = await Supabase.instance.client
      .from('user_photos')
      .select()
      .eq('user_id', userId)
      .eq('is_selfie', false)
      .eq('moderation_status', 'approved')
      .order('order_index');
  return List<Map<String, dynamic>>.from(data as List);
});

final userPromptsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final data = await Supabase.instance.client
      .from('user_prompts')
      .select()
      .eq('user_id', userId);
  return List<Map<String, dynamic>>.from(data as List);
});
