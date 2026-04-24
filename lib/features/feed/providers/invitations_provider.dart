import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/invitation_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';

final invitationsProvider = FutureProvider.autoDispose.family<List<InvitationModel>, _InvitationFilter>(
  (ref, filter) async {
    final client = Supabase.instance.client;
    final currentUserId = ref.read(currentUserIdProvider);

    // Fetch blocked user IDs
    List<String> blockedIds = [];
    if (currentUserId != null) {
      final blocks = await client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUserId);
      blockedIds = (blocks as List)
          .map((b) => b['blocked_id'] as String)
          .toList();
    }

    var query = client
        .from('invitations')
        .select(
          '*, '
          'owner:users(id, name, age, gender, city_id, verified, photos:user_photos(url, is_primary, is_selfie, order_index)), '
          'applications(status, applicant:users(id, photos:user_photos(url, is_selfie, order_index)))',
        )
        .eq('status', 'active')
        .eq('flow_type', filter.flowType.name)
        .gt('expires_at', DateTime.now().toIso8601String());

    if (filter.cityId != null) {
      query = query.eq('city_id', filter.cityId!);
    }
    if (filter.category != null) {
      query = query.eq('category', filter.category!.name);
    }
    // Exclude blocked users' invitations
    if (blockedIds.isNotEmpty) {
      query = query.not('owner_id', 'in', '(${blockedIds.join(',')})');
    }

    final data = await query.order('created_at', ascending: false).limit(30);

    return (data as List).map((row) {
      // ── Owner ─────────────────────────────────────────────────────────────
      final ownerRow = row['owner'] as Map<String, dynamic>?;
      final owner = ownerRow != null
          ? UserModel(
              id: ownerRow['id'] as String,
              phone: '',
              name: ownerRow['name'] as String? ?? '',
              age: ownerRow['age'] as int? ?? 0,
              gender: ownerRow['gender'] as String? ?? '',
              verified: ownerRow['verified'] as bool? ?? false,
              createdAt: DateTime.now(),
            )
          : null;

      final photos = (ownerRow?['photos'] as List<dynamic>?) ?? [];
      final sortedPhotos = photos
          .cast<Map<String, dynamic>>()
          .where((p) => p['is_selfie'] == false)
          .toList()
        ..sort((a, b) =>
            (a['order_index'] as int? ?? 99)
                .compareTo(b['order_index'] as int? ?? 99));
      final ownerPhotoUrl = sortedPhotos.firstOrNull?['url'] as String?;

      // ── Applicant photos (up to 4 pending applicants) ─────────────────────
      final apps = (row['applications'] as List<dynamic>?) ?? [];
      final pendingApps = apps
          .cast<Map<String, dynamic>>()
          .where((a) => a['status'] == 'pending')
          .toList();

      final applicantPhotoUrls = pendingApps.expand<String>((a) {
        final applicant = a['applicant'] as Map<String, dynamic>?;
        if (applicant == null) return [];
        final appPhotos = (applicant['photos'] as List<dynamic>?) ?? [];
        return appPhotos
            .cast<Map<String, dynamic>>()
            .where((p) => p['is_selfie'] == false)
            .map((p) => p['url'] as String)
            .take(1);
      }).take(4).toList();

      return InvitationModel.fromJson({...row, 'owner': null}).copyWith(
        owner: owner,
        ownerPhotoUrl: ownerPhotoUrl,
        applicationCount: pendingApps.length,
        applicantPhotoUrls: applicantPhotoUrls,
      );
    }).where((inv) => inv.ownerPhotoUrl != null).toList();
  },
);

class _InvitationFilter {
  final InvitationFlowType flowType;
  final String? cityId;
  final InvitationCategory? category;

  const _InvitationFilter({
    required this.flowType,
    this.cityId,
    this.category,
  });

  @override
  bool operator ==(Object other) =>
      other is _InvitationFilter &&
      other.flowType == flowType &&
      other.cityId == cityId &&
      other.category == category;

  @override
  int get hashCode => Object.hash(flowType, cityId, category);
}

InvitationFilter invitationFilter({
  required InvitationFlowType flowType,
  String? cityId,
  InvitationCategory? category,
}) => _InvitationFilter(flowType: flowType, cityId: cityId, category: category);

typedef InvitationFilter = _InvitationFilter;
