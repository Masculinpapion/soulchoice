import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/invitation_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/locale_provider.dart';

String? _cityName(Map<String, dynamic>? city, String? lang) {
  if (city == null) return null;
  switch (lang) {
    case 'ru': return city['name_ru'] as String? ?? city['name'] as String?;
    case 'tr': return city['name_tr'] as String? ?? city['name'] as String?;
    default:   return city['name_en'] as String? ?? city['name'] as String?;
  }
}

final invitationsProvider = FutureProvider.autoDispose.family<List<InvitationModel>, _InvitationFilter>(
  (ref, filter) async {
    final client = Supabase.instance.client;
    final currentUserId = ref.read(currentUserIdProvider);
    final lang = ref.watch(localeProvider)?.languageCode;

    // Fetch blocked IDs + current user preferences
    List<String> blockedIds = [];
    String? myGender;
    String showGender = 'opposite';
    int minAge = 21;
    int maxAge = 60;
    if (currentUserId != null) {
      final results = await Future.wait<dynamic>([
        client.from('blocks').select('blocked_id').eq('blocker_id', currentUserId),
        client.from('users').select('gender, show_gender, min_age, max_age').eq('id', currentUserId).maybeSingle(),
      ]);
      blockedIds = (results[0] as List).map((b) => b['blocked_id'] as String).toList();
      final userRow = results[1] as Map<String, dynamic>?;
      myGender = userRow?['gender'] as String?;
      showGender = userRow?['show_gender'] as String? ?? 'opposite';
      minAge = userRow?['min_age'] as int? ?? 21;
      maxAge = userRow?['max_age'] as int? ?? 60;
    }

    // Hedef cinsiyet belirle
    String? targetGender;
    switch (showGender) {
      case 'opposite':
        targetGender = myGender == 'male' ? 'female' : myGender == 'female' ? 'male' : null;
      case 'male':
        targetGender = 'male';
      case 'female':
        targetGender = 'female';
      case 'all':
        targetGender = null;
    }

    var query = client
        .from('invitations')
        .select(
          '*, '
          'city:cities(name, name_ru, name_tr, name_en), '
          'owner:users(id, name, age, gender, show_gender, city_id, verified, is_deleted, photos:user_photos(url, is_primary, is_selfie, order_index)), '
          'applications(status, applicant:users(id, photos:user_photos(url, is_selfie, order_index)))',
        )
        .eq('status', 'active')
        .eq('flow_type', filter.flowType.name)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());

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
      if (ownerRow?['is_deleted'] == true) return null;

      // Owner filter: bidirectional — her iki tarafın tercihi de uygulanır
      // Onboarding'de zorunlu seçim olduğu için her kullanıcı bilinçli ifade etti.
      if (myGender != null) {
        final ownerShowGender = ownerRow?['show_gender'] as String? ?? 'all';
        final ownerGender = ownerRow?['gender'] as String? ?? '';
        if (ownerShowGender == 'opposite') {
          final wantsToBeSeenBy = ownerGender == 'male' ? 'female' : 'male';
          if (myGender != wantsToBeSeenBy) return null;
        } else if (ownerShowGender == 'male' && myGender != 'male') {
          return null;
        } else if (ownerShowGender == 'female' && myGender != 'female') {
          return null;
        }
      }
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
            .map((p) => p['url'] as String?).whereType<String>()
            .take(1);
      }).take(4).toList();

      final cityRow = row['city'] as Map<String, dynamic>?;

      return InvitationModel.fromJson({...row, 'owner': null, 'city': null}).copyWith(
        owner: owner,
        ownerPhotoUrl: ownerPhotoUrl,
        applicationCount: pendingApps.length,
        applicantPhotoUrls: applicantPhotoUrls,
        cityName: _cityName(cityRow, lang),
      );
    }).whereType<InvitationModel>()
        .where((inv) => inv.ownerPhotoUrl != null)
        // Viewer filter: sen kimi görmek istiyorsun (kendi kartların her zaman görünür)
        .where((inv) => inv.owner?.id == currentUserId || targetGender == null || inv.owner?.gender == targetGender)
        .where((inv) {
          final age = inv.owner?.age ?? 0;
          return age >= minAge && age <= maxAge;
        })
        .toList();
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
