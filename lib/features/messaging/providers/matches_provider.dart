import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';

class MatchPreview {
  final String matchId;
  // null = karşı taraf hesabını silmiş (DB SET NULL)
  final String? otherUserId;
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
    this.otherUserId,
    required this.otherName,
    required this.otherAge,
    this.otherPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    this.meetingDate,
    this.archivedAt,
  });

  bool get isDeleted => otherUserId == null;

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

  final data = await client
      .from('matches')
      .select('id, user1_id, user2_id, meeting_date, archived_at')
      .or('user1_id.eq.$uid,user2_id.eq.$uid')
      // archived olmayan match'leri önce göster (aynı kişi ile birden fazla
      // match varsa seen.containsKey eski archived olanı tutmasın)
      .order('archived_at', ascending: true, nullsFirst: true)
      .order('created_at', ascending: false);

  final matches = (data as List).cast<Map<String, dynamic>>();
  if (matches.isEmpty) return [];

  final matchIds = matches.map((m) => m['id'] as String).toList();
  final otherUserIds = matches.map((m) {
    final u1 = m['user1_id'] as String?;
    final u2 = m['user2_id'] as String?;
    return u1 == uid ? u2 : u1;
  }).toList();
  final uniqueOtherIds = otherUserIds.whereType<String>().toSet().toList();

  // 3 sorgu paralel: kullanıcı bilgisi + foto + mesajlar
  final results = await Future.wait([
    client
        .from('users')
        .select('id, name, age')
        .inFilter('id', uniqueOtherIds),
    client
        .from('user_photos')
        .select('user_id, url')
        .inFilter('user_id', uniqueOtherIds)
        .eq('is_primary', true),
    client
        .from('messages')
        .select('id, match_id, sender_id, content, created_at, read_at')
        .inFilter('match_id', matchIds)
        .order('created_at', ascending: false),
  ]);

  // Dart'ta index'le
  final userMap = <String, Map<String, dynamic>>{
    for (final r in (results[0] as List).cast<Map<String, dynamic>>())
      r['id'] as String: r,
  };
  final photoMap = <String, String>{
    for (final r in (results[1] as List).cast<Map<String, dynamic>>())
      r['user_id'] as String: r['url'] as String,
  };

  final lastMsgMap = <String, Map<String, dynamic>>{};
  final unreadCountMap = <String, int>{};
  for (final msg in (results[2] as List).cast<Map<String, dynamic>>()) {
    final mid = msg['match_id'] as String;
    // Sıralı geldiği için ilk karşılaşılan en yeni mesajdır
    lastMsgMap.putIfAbsent(mid, () => msg);
    if (msg['sender_id'] != uid && msg['read_at'] == null) {
      unreadCountMap[mid] = (unreadCountMap[mid] ?? 0) + 1;
    }
  }

  final seen = <String, MatchPreview>{};
  for (int i = 0; i < matches.length; i++) {
    final m = matches[i];
    final matchId = m['id'] as String;
    final otherUserId = otherUserIds[i];
    final userRow = userMap[otherUserId];
    // Silinmiş kullanıcıda kişi bazlı dedup yapılamaz — match bazında tut
    final seenKey = otherUserId ?? 'match:$matchId';
    if (seen.containsKey(seenKey)) continue;

    final lastMsg = lastMsgMap[matchId];
    seen[seenKey] = MatchPreview(
      matchId: matchId,
      otherUserId: otherUserId,
      otherName: userRow?['name'] as String? ?? '—',
      otherAge: userRow?['age'] as int? ?? 0,
      otherPhotoUrl: photoMap[otherUserId],
      lastMessage: lastMsg?['content'] as String?,
      lastMessageTime: lastMsg != null
          ? DateTime.parse(lastMsg['created_at'] as String)
          : null,
      unreadCount: unreadCountMap[matchId] ?? 0,
      meetingDate: m['meeting_date'] != null
          ? DateTime.parse(m['meeting_date'] as String)
          : null,
      archivedAt: m['archived_at'] != null
          ? DateTime.parse(m['archived_at'] as String)
          : null,
    );
  }
  final result = seen.values.toList();

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
