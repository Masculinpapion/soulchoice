import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';

class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;
  final String? actorName;
  final String? actorPhotoUrl;

  /// Aynı sohbete ait gruplanmış mesaj bildirimlerinin tüm id'leri (kendisi dahil).
  final List<String> groupIds;
  final int groupCount;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.isRead,
    required this.createdAt,
    this.actorName,
    this.actorPhotoUrl,
    this.groupIds = const [],
    this.groupCount = 1,
  });

  List<String> get allIds => groupIds.isEmpty ? [id] : groupIds;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        payload: (json['payload'] as Map<String, dynamic>?) ?? {},
        isRead: json['read_at'] != null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  NotificationItem copyWithActor({String? actorName, String? actorPhotoUrl}) =>
      NotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        payload: payload,
        isRead: isRead,
        createdAt: createdAt,
        actorName: actorName,
        actorPhotoUrl: actorPhotoUrl,
        groupIds: groupIds,
        groupCount: groupCount,
      );

  NotificationItem copyGrouped({
    required List<String> groupIds,
    required int groupCount,
    required bool isRead,
  }) =>
      NotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        payload: payload,
        isRead: isRead,
        createdAt: createdAt,
        actorName: actorName,
        actorPhotoUrl: actorPhotoUrl,
        groupIds: groupIds,
        groupCount: groupCount,
      );

  String get routePath {
    // Selfie bildirimleri akışa göre yönlenir: red → yeniden çekim ekranı
    // (16.07 fix: payload boş olduğundan /feed push ediliyordu → siyah ekran)
    if (type == 'selfie_rejected') return '/profile/selfie';
    if (type == 'selfie_approved') return '/feed';
    final invId = payload['invitation_id'] as String?;
    final matchId = payload['match_id'] as String?;
    if (matchId != null) return '/chat/$matchId';
    if (invId != null) return '/invitation/$invId';
    return '/feed';
  }

  IconData get iconData {
    switch (type) {
      case 'selected':
        return Icons.celebration_rounded;
      case 'not_selected':
        return Icons.sentiment_dissatisfied_rounded;
      case 'new_message':
        return Icons.chat_rounded;
      case 'new_application':
        return Icons.waving_hand_rounded;
      case 'selfie_approved':
        return Icons.verified_user_rounded;
      case 'selfie_rejected':
        return Icons.cancel_rounded;
      case 'meeting_reminder':
        return Icons.schedule_rounded;
      case 'feedback_request':
        return Icons.rate_review_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];

  final client = Supabase.instance.client;

  final data = await client
      .from('notifications')
      .select()
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(100);

  final rows = (data as List).cast<Map<String, dynamic>>();
  if (rows.isEmpty) return [];

  final items = rows.map((r) => NotificationItem.fromJson(r)).toList();

  // Bildirimlere sebep olan kişilerin (actor) id'lerini topla — tek toplu
  // sorguyla users+user_photos'a join et, N+1 sorgu olmasın.
  final actorIds = items
      .map((i) => i.payload['actor_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();

  if (actorIds.isEmpty) return items;

  final actorRows = await client
      .from('users')
      .select(
        'id, name, photos:user_photos(url, is_primary, is_selfie, order_index)',
      )
      .inFilter('id', actorIds);

  final actors = <String, ({String name, String? photoUrl})>{};
  for (final u in (actorRows as List).cast<Map<String, dynamic>>()) {
    final photos = (u['photos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((p) => p['is_selfie'] == false)
        .toList()
      ..sort((a, b) => (a['order_index'] as int? ?? 99)
          .compareTo(b['order_index'] as int? ?? 99));
    actors[u['id'] as String] = (
      name: u['name'] as String? ?? '',
      photoUrl: photos.firstOrNull?['url'] as String?,
    );
  }

  final mapped = items.map((item) {
    final actorId = item.payload['actor_id'] as String?;
    final actor = actorId != null ? actors[actorId] : null;
    if (actor == null) return item;
    return item.copyWithActor(actorName: actor.name, actorPhotoUrl: actor.photoUrl);
  }).toList();

  return _groupMessages(mapped);
});

/// Aynı sohbetin (match) mesaj bildirimlerini tek satırda toplar: temsilci
/// en yenisi, groupCount toplam, biri bile okunmadıysa grup okunmamış sayılır.
/// Diğer bildirim türleri olduğu gibi geçer.
List<NotificationItem> _groupMessages(List<NotificationItem> items) {
  final result = <NotificationItem>[];
  final msgIndex = <String, int>{};
  for (final item in items) {
    if (item.type != 'new_message') {
      result.add(item);
      continue;
    }
    final key = (item.payload['match_id'] ??
            item.payload['actor_id'] ??
            item.id)
        .toString();
    final at = msgIndex[key];
    if (at == null) {
      msgIndex[key] = result.length;
      result.add(item);
    } else {
      final rep = result[at];
      result[at] = rep.copyGrouped(
        groupIds: [...rep.allIds, item.id],
        groupCount: rep.groupCount + 1,
        isRead: rep.isRead && item.isRead,
      );
    }
  }
  return result;
}

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
