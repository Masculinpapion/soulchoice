import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  return Supabase.instance.client
      .from('users')
      // 31.07: select('*') KULLANMA — phone/billing_email/fcm_token kolonları
      // gizlilik gereği kapatıldı (herkes tüm telefonları çekebiliyordu),
      // '*' bu kolonları da isteyeceği için sorgu tümden reddedilir.
      .select(
          'id, name, age, gender, city_id, bio, job, education, interests, '
          'verified, subscription_status, premium_until, selfie_status, '
          'selfie_rejected_reason, show_gender, min_age, max_age, banned, '
          'suspended_at, suspension_reason, is_deleted, is_admin, locale, '
          'free_application_used, free_applications_used, no_show_count, created_at, last_seen_at, '
          'city:cities(name, name_ru, name_tr, name_en, country)')
      .eq('id', userId)
      .maybeSingle();
});

final userPhotosProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final data = await Supabase.instance.client
      .from('user_photos')
      .select()
      .eq('user_id', userId)
      .eq('is_selfie', false)
      .eq('moderation_status', 'approved')
      .order('is_primary', ascending: false);
  return List<Map<String, dynamic>>.from(data as List);
});

final userPromptsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final data = await Supabase.instance.client
      .from('user_prompts')
      .select()
      .eq('user_id', userId);
  return List<Map<String, dynamic>>.from(data as List);
});
