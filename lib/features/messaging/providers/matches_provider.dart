import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';

class MatchPreview {
  final String matchId;
  final String otherUserId;
  final String otherName;
  final int otherAge;
  final String? otherPhotoUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final DateTime? meetingDate;
  final DateTime? archivedAt;

  const MatchPreview({
    required this.matchId,
    required this.otherUserId,
    required this.otherName,
    required this.otherAge,
    this.otherPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    this.meetingDate,
    this.archivedAt,
  });

  bool get isArchived {
    if (archivedAt != null) return true;
    if (meetingDate == null) return false;
    return DateTime.now().isAfter(meetingDate!.add(const Duration(hours: 24)));
  }
}

final matchesProvider =
    FutureProvider.autoDispose<List<MatchPreview>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];

  final client = Supabase.instance.client;

  // Fetch matches where current user is participant
  final data = await client
      .from('matches')
      .select(
          'id, user1_id, user2_id, meeting_date, archived_at')
      .or('user1_id.eq.$uid,user2_id.eq.$uid')
      .order('created_at', ascending: false);

  final matches = (data as List).cast<Map<String, dynamic>>();
  if (matches.isEmpty) return [];

  final result = <MatchPreview>[];

  for (final m in matches) {
    final matchId = m['id'] as String;
    final user1Id = m['user1_id'] as String;
    final user2Id = m['user2_id'] as String;
    final otherUserId = user1Id == uid ? user2Id : user1Id;
    final meetingDate = m['meeting_date'] != null
        ? DateTime.parse(m['meeting_date'] as String)
        : null;
    final archivedAt = m['archived_at'] != null
        ? DateTime.parse(m['archived_at'] as String)
        : null;

    // Fetch other user info + primary photo
    final userRow = await client
        .from('users')
        .select('name, age')
        .eq('id', otherUserId)
        .maybeSingle();
    if (userRow == null) continue;

    final photoRow = await client
        .from('user_photos')
        .select('url')
        .eq('user_id', otherUserId)
        .eq('is_primary', true)
        .maybeSingle();

    // Last message
    final lastMsgRow = await client
        .from('messages')
        .select('content, created_at')
        .eq('match_id', matchId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    // Unread count
    final unreadRes = await client
        .from('messages')
        .select('id')
        .eq('match_id', matchId)
        .isFilter('read_at', null)
        .neq('sender_id', uid);

    result.add(MatchPreview(
      matchId: matchId,
      otherUserId: otherUserId,
      otherName: userRow['name'] as String,
      otherAge: userRow['age'] as int,
      otherPhotoUrl: photoRow?['url'] as String?,
      lastMessage: lastMsgRow?['content'] as String?,
      lastMessageTime: lastMsgRow != null
          ? DateTime.parse(lastMsgRow['created_at'] as String)
          : null,
      unreadCount: (unreadRes as List).length,
      meetingDate: meetingDate,
      archivedAt: archivedAt,
    ));
  }

  // Sort by last message time desc
  result.sort((a, b) {
    final at = a.lastMessageTime;
    final bt = b.lastMessageTime;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });

  return result;
});

final activeMatchesProvider =
    Provider.autoDispose<AsyncValue<List<MatchPreview>>>((ref) {
  return ref.watch(matchesProvider).whenData(
        (list) => list.where((m) => !m.isArchived).toList(),
      );
});

final archivedMatchesProvider =
    Provider.autoDispose<AsyncValue<List<MatchPreview>>>((ref) {
  return ref.watch(matchesProvider).whenData(
        (list) => list.where((m) => m.isArchived).toList(),
      );
});
