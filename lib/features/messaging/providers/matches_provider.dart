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
  final DateTime createdAt;

  const MatchPreview({
    required this.matchId,
    this.otherUserId,
    required this.otherName,
    required this.otherAge,
    this.otherPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    required this.createdAt,
  });

  bool get isDeleted => otherUserId == null;

  /// Henüz hiç mesajlaşılmamış eşleşme — listede en üstte, rozetle gösterilir
  bool get isNewMatch => lastMessage == null && !isDeleted;
}

final matchesProvider =
    FutureProvider.autoDispose<List<MatchPreview>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];

  final client = Supabase.instance.client;

  final data = await client
      .from('matches')
      .select('id, user1_id, user2_id, created_at, '
          'user1_hidden_at, user2_hidden_at')
      .or('user1_id.eq.$uid,user2_id.eq.$uid')
      // Sohbetler kalıcıdır (20.07.2026 kararı) — aynı kişiyle birden fazla
      // match varsa seen.containsKey en yenisini tutar
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
    final lastMsg = lastMsgMap[matchId];

    // Tek-taraflı gizleme: benim hidden_at'imden sonra yeni mesaj yoksa gizle.
    // Yeni mesaj gelince (created_at > hidden_at) sohbet otomatik geri döner.
    final myHiddenRaw =
        (m['user1_id'] == uid) ? m['user1_hidden_at'] : m['user2_hidden_at'];
    if (myHiddenRaw != null) {
      final hiddenAt = DateTime.parse(myHiddenRaw as String);
      final lastRaw = lastMsg?['created_at'] as String?;
      if (lastRaw == null || !DateTime.parse(lastRaw).isAfter(hiddenAt)) {
        continue;
      }
    }

    // Silinmiş kullanıcıda kişi bazlı dedup yapılamaz — match bazında tut
    final seenKey = otherUserId ?? 'match:$matchId';
    if (seen.containsKey(seenKey)) continue;
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
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
  final result = seen.values.toList();

  // Mesajsız (yeni) eşleşmeler EN ÜSTTE — kullanıcı seçildiğini kaçırmasın.
  // Kendi aralarında en yeni match önce; mesajlı sohbetler son mesaja göre.
  result.sort((a, b) {
    final at = a.lastMessageTime;
    final bt = b.lastMessageTime;
    if (at == null && bt == null) return b.createdAt.compareTo(a.createdAt);
    if (at == null) return -1;
    if (bt == null) return 1;
    return bt.compareTo(at);
  });

  return result;
});

/// Bu kullanıcıyla mevcut match id'si (en yeni) — profildeki
/// "Mesaj yaz" girişi için. Match yoksa null.
final matchWithUserProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, otherUserId) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  final rows = await Supabase.instance.client
      .from('matches')
      .select('id')
      .or('and(user1_id.eq.$uid,user2_id.eq.$otherUserId),'
          'and(user1_id.eq.$otherUserId,user2_id.eq.$uid)')
      .order('created_at', ascending: false)
      .limit(1);
  final list = rows as List;
  if (list.isEmpty) return null;
  return (list.first as Map<String, dynamic>)['id'] as String;
});

