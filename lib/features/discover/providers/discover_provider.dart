import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../data/models/invitation_model.dart';
import '../../../data/models/user_model.dart';

String? _cityName(Map<String, dynamic>? city, String? lang) {
  if (city == null) return null;
  switch (lang) {
    case 'ru': return city['name_ru'] as String? ?? city['name'] as String?;
    case 'tr': return city['name_tr'] as String? ?? city['name'] as String?;
    default:   return city['name_en'] as String? ?? city['name'] as String?;
  }
}

final discoverProvider =
    FutureProvider.autoDispose.family<List<InvitationModel>, String?>((ref, cityId) async {
  final currentUserId = ref.read(currentUserIdProvider);
  final lang = ref.watch(localeProvider)?.languageCode;
  final client = Supabase.instance.client;

  // Fetch current user gender + blocked IDs (sadece karşı cinsiyet gösterilir)
  List<String> blockedIds = [];
  String? myGender;
  String? targetGender;
  if (currentUserId != null) {
    final results = await Future.wait<dynamic>([
      client.from('blocks').select('blocked_id').eq('blocker_id', currentUserId),
      client.from('users').select('gender').eq('id', currentUserId).maybeSingle(),
    ]);
    blockedIds = ((results[0] as List).map((b) => b['blocked_id'] as String).toList());
    final userRow = results[1] as Map<String, dynamic>?;
    myGender = userRow?['gender'] as String?;
    targetGender = myGender == 'male' ? 'female' : myGender == 'female' ? 'male' : null;
  }

  var query = client.from('invitations').select(
        '*, '
        'city:cities(name, name_ru, name_tr, name_en), '
        'owner:users(id, name, age, gender, subscription_status, is_deleted, '
        'photos:user_photos(url, is_primary, is_selfie, order_index))',
      );

  query = query
      .eq('status', 'active')
      .gt('expires_at', DateTime.now().toUtc().toIso8601String());

  if (currentUserId != null) {
    query = query.neq('owner_id', currentUserId);
  }
  if (blockedIds.isNotEmpty) {
    query = query.not('owner_id', 'in', '(${blockedIds.join(',')})');
  }

  final rawData = await query.order('created_at', ascending: false).limit(100);

  // Hibrit: cityId varsa once o sehirdekiler (shuffle), sonra digerleri (shuffle).
  // cityId yoksa hepsi shuffle.
  final List<Map<String, dynamic>> rows = (rawData as List).cast<Map<String, dynamic>>().toList();
  if (cityId != null) {
    final cityMatched = rows.where((r) => r['city_id'] == cityId).toList()..shuffle();
    final others = rows.where((r) => r['city_id'] != cityId).toList()..shuffle();
    rows
      ..clear()
      ..addAll([...cityMatched, ...others]);
  } else {
    rows.shuffle();
  }

  final list = rows.map((row) {
    final ownerRow = row['owner'] as Map<String, dynamic>?;
    if (ownerRow?['is_deleted'] == true) return null;

    final owner = ownerRow != null
        ? UserModel(
            id: ownerRow['id'] as String,
            phone: '',
            name: ownerRow['name'] as String? ?? '',
            age: ownerRow['age'] as int? ?? 0,
            gender: ownerRow['gender'] as String? ?? '',
            subscriptionStatus: ownerRow['subscription_status'] as String? ?? 'free',
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

    return InvitationModel.fromJson({...row, 'owner': null, 'city': null}).copyWith(
      owner: owner,
      ownerPhotoUrl: ownerPhotoUrl,
      cityName: _cityName(cityRow, lang),
    );
  }).whereType<InvitationModel>()
      .where((inv) => inv.ownerPhotoUrl != null)
      .where((inv) => targetGender == null || inv.owner?.gender == targetGender)
      .toList();

  // (shuffle yukarida raw row asamasinda yapildi — sira korunmali)

  // Kullanıcı başına 1 kart — aynı kişinin birden fazla daveti olsa bile
  final seen = <String>{};
  return list.where((inv) => inv.owner?.id != null && seen.add(inv.owner!.id)).toList();
});
