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

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

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

  String get routePath {
    final invId = payload['invitation_id'] as String?;
    final matchId = payload['match_id'] as String?;
    if (matchId != null) return '/chat/$matchId';
    if (invId != null) return '/invitation/$invId';
    return '/feed';
  }

  String get iconEmoji {
    switch (type) {
      case 'selected':
        return '🎉';
      case 'not_selected':
        return '😔';
      case 'new_message':
        return '💬';
      case 'new_application':
        return '👋';
      case 'selfie_approved':
        return '✅';
      case 'selfie_rejected':
        return '❌';
      case 'meeting_reminder':
        return '⏰';
      case 'feedback_request':
        return '❓';
      default:
        return '🔔';
    }
  }
}

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];

  final data = await Supabase.instance.client
      .from('notifications')
      .select()
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(100);

  return (data as List)
      .map((r) => NotificationItem.fromJson(r as Map<String, dynamic>))
      .toList();
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
