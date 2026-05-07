import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/models/invitation_model.dart';
import '../../../data/models/user_model.dart';

final discoverProvider =
    FutureProvider.autoDispose.family<List<InvitationModel>, String?>((ref, cityId) async {
  final currentUserId = ref.read(currentUserIdProvider);
  final client = Supabase.instance.client;

  // Fetch current user gender + show_gender + blocked IDs
  List<String> blockedIds = [];
  String? myGender;
  String? targetGender;
  if (currentUserId != null) {
    final results = await Future.wait<dynamic>([
      client.from('blocks').select('blocked_id').eq('blocker_id', currentUserId),
      client.from('users').select('gender, show_gender').eq('id', currentUserId).maybeSingle(),
    ]);
    blockedIds = ((results[0] as List).map((b) => b['blocked_id'] as String).toList());
    final userRow = results[1] as Map<String, dynamic>?;
    myGender = userRow?['gender'] as String?;
    final showGender = userRow?['show_gender'] as String? ?? 'opposite';
    if (showGender == 'opposite') {
      targetGender = myGender == 'male' ? 'female' : myGender == 'female' ? 'male' : null;
    } else if (showGender == 'male') {
      targetGender = 'male';
    } else if (showGender == 'female') {
      targetGender = 'female';
    } else {
      targetGender = null;
    }
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
  if (cityId != null) {
    query = query.eq('city_id', cityId);
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
  }).whereType<InvitationModel>()
      .where((inv) => inv.ownerPhotoUrl != null)
      .where((inv) => targetGender == null || inv.owner?.gender == targetGender)
      .toList();

  list.shuffle();

  // Kullanıcı başına 1 kart — aynı kişinin birden fazla daveti olsa bile
  final seen = <String>{};
  return list.where((inv) => inv.owner?.id != null && seen.add(inv.owner!.id)).toList();
});
