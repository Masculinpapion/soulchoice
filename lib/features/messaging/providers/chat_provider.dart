import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/message_model.dart';

final messagesProvider =
    FutureProvider.autoDispose.family<List<MessageModel>, String>((ref, matchId) async {
  final data = await Supabase.instance.client
      .from('messages')
      .select()
      .eq('match_id', matchId)
      .order('created_at');
  return (data as List).map((r) => MessageModel.fromJson(r)).toList();
});
