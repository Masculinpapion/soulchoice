import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns whether the current user has favorited [targetUserId].
final isFavoriteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, targetUserId) async {
  final currentUid = Supabase.instance.client.auth.currentUser?.id;
  if (currentUid == null) return false;
  final result = await Supabase.instance.client
      .from('favorites')
      .select('id')
      .eq('user_id', currentUid)
      .eq('favorited_user_id', targetUserId)
      .maybeSingle();
  return result != null;
});
