import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final applicantsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, invitationId) async {
  final client = Supabase.instance.client;
  final currentUserId = client.auth.currentUser!.id;

  final blockedRows = await client
      .from('blocks')
      .select('blocked_id')
      .eq('blocker_id', currentUserId);
  final blockedIds = (blockedRows as List).map((r) => r['blocked_id'] as String).toSet();

  // pending + accepted başvurular
  final apps = await client
      .from('applications')
      .select('id, status, created_at, applicant:users(id, name, age, gender, subscription_status, bio, photos:user_photos(url, is_primary))')
      .eq('invitation_id', invitationId)
      .inFilter('status', ['pending', 'accepted'])
      .order('created_at');

  // Bu davete ait match'ler (accepted olanlar için chat ID)
  final matches = await client
      .from('matches')
      .select('id, user1_id, user2_id')
      .eq('invitation_id', invitationId);

  final matchList = List<Map<String, dynamic>>.from(matches as List);

  return List<Map<String, dynamic>>.from(apps as List).where((app) {
    final applicantId = (app['applicant'] as Map?)?['id'] as String?;
    return applicantId == null || !blockedIds.contains(applicantId);
  }).map((app) {
    final applicantId = (app['applicant'] as Map?)?['id'] as String?;
    final matchRow = matchList.firstWhere(
      (m) => m['user1_id'] == applicantId || m['user2_id'] == applicantId,
      orElse: () => {},
    );
    return {...app, 'match_id': matchRow['id'] as String?};
  }).toList();
});
