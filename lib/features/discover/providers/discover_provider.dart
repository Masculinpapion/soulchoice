import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/models/invitation_model.dart';
import '../../../data/models/user_model.dart';

final discoverProvider =
    FutureProvider.autoDispose<List<InvitationModel>>((ref) async {
  final currentUserId = ref.read(currentUserIdProvider);
  final client = Supabase.instance.client;

  // Fetch blocked user IDs
  List<String> blockedIds = [];
  if (currentUserId != null) {
    final blocks = await client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', currentUserId);
    blockedIds =
        (blocks as List).map((b) => b['blocked_id'] as String).toList();
  }

  var query = client.from('invitations').select(
        '*, '
        'city:cities(name), '
        'owner:users(id, name, age, gender, verified, is_deleted, '
        'photos:user_photos(url, is_primary, is_selfie, order_index))',
      );

  query = query
      .eq('status', 'active')
      .gt('expires_at', DateTime.now().toIso8601String());

  if (currentUserId != null) {
    query = query.neq('owner_id', currentUserId);
  }
  if (blockedIds.isNotEmpty) {
    query = query.not('owner_id', 'in', '(${blockedIds.join(',')})');
  }

  final data = await query.order('created_at', ascending: false).limit(50);

  final list = (data as List).map((row) {
    final ownerRow = row['owner'] as Map<String, dynamic>?;
    if (ownerRow?['is_deleted'] == true) return null;
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
      ..sort((a, b) => (a['order_index'] as int? ?? 99)
          .compareTo(b['order_index'] as int? ?? 99));
    final ownerPhotoUrl = sortedPhotos.firstOrNull?['url'] as String?;

    final cityRow = row['city'] as Map<String, dynamic>?;
    final cityName = cityRow?['name'] as String?;

    return InvitationModel.fromJson({...row, 'owner': null, 'city': null}).copyWith(
      owner: owner,
      ownerPhotoUrl: ownerPhotoUrl,
      cityName: cityName,
    );
  }).whereType<InvitationModel>().where((inv) => inv.ownerPhotoUrl != null).toList();

  list.shuffle();
  return list;
});
