import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/invitation_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../logic/feed_visibility_rules.dart';

String? _cityName(Map<String, dynamic>? city, String? lang) {
  if (city == null) return null;
  switch (lang) {
    case 'ru': return city['name_ru'] as String? ?? city['name'] as String?;
    case 'tr': return city['name_tr'] as String? ?? city['name'] as String?;
    default:   return city['name_en'] as String? ?? city['name'] as String?;
  }
}

/// 22.08 — SONSUZ KAYDIRMA: tek istekte inen dilim boyutu. Kullanıcı yüklü
/// listenin sonuna yaklaşınca [feedPageCountProvider] artırılır; sorgu
/// 0..(sayfa×boyut) aralığını yeniden çeker (tam yeniden çekim = sayfalar
/// arası tutarlı sıra; rebirth/sıra kayması duplikat üretemez).
const feedPageSize = 120;

/// Filter başına yüklü sayfa sayısı. autoDispose: sekme/filtre değişince sıfırlanır.
final feedPageCountProvider =
    StateProvider.autoDispose.family<int, _InvitationFilter>((ref, _) => 1);

/// Sunucuda daha kart var mı? (son istekte istenen aralık tamamen dolduysa true)
final feedHasMoreProvider =
    StateProvider.autoDispose.family<bool, _InvitationFilter>((ref, _) => true);

final invitationsProvider = FutureProvider.autoDispose.family<List<InvitationModel>, _InvitationFilter>(
  (ref, filter) async {
    final client = Supabase.instance.client;
    final pageCount = ref.watch(feedPageCountProvider(filter));
    final currentUserId = ref.read(currentUserIdProvider);
    final lang = ref.watch(localeProvider)?.languageCode;

    // Fetch blocked IDs + current user preferences
    List<String> blockedIds = [];
    String? myGender;
    int minAge = 21;
    int maxAge = 60;
    if (currentUserId != null) {
      final results = await Future.wait<dynamic>([
        // Çift yönlü gizleme: engellediğim + beni engelleyen (SECURITY DEFINER RPC)
        client.rpc('hidden_from_feed'),
        client.from('users').select('gender, min_age, max_age').eq('id', currentUserId).maybeSingle(),
      ]);
      blockedIds =
          (results[0] as List).map((b) => b['user_id'] as String).toList();
      final userRow = results[1] as Map<String, dynamic>?;
      myGender = userRow?['gender'] as String?;
      minAge = userRow?['min_age'] as int? ?? 21;
      maxAge = userRow?['max_age'] as int? ?? 60;
    }

    final targetGender = myGender == 'male' ? 'female' : myGender == 'female' ? 'male' : null;

    var query = client
        .from('invitations')
        .select(
          '*, '
          'city:cities(name, name_ru, name_tr, name_en), '
          // 20.08: !inner → sahip filtresi SUNUCUDA uygulanır (karşı cins + yaş aralığı);
          // önceden 30 kart iniyor, yarısı istemcide eleniyordu (kullanıcı ~15 görürdü,
          // 30'dan sonraki karşı-cins kartlar hiç gelmezdi).
          'owner:users!inner(id, name, age, gender, city_id, subscription_status, is_deleted, photos:user_photos(url, is_primary, is_selfie, order_index)), '
          // 03.09 (kalite teşhisi B1): başvuru embed'i HAFİF — eskiden her ilanla
          // birlikte TÜM başvuranların TÜM fotoğrafları iniyordu (ilk popüler ilanda
          // 200 başvuru × N foto). Fotoğraflar aşağıda tek toplu sorguyla, yalnız
          // gösterilecek ≤4 pending başvuran için çekilir; sayaç/gizleme kuralı
          // tüm başvuru satırlarını görmeye devam eder.
          'applications(status, applicant_id)',
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
    // 20.08: sunucu tarafı sahip filtresi — kendi kartım her zaman, diğerleri
    // karşı cins + yaş aralığı (istemci filtresi güvenlik ağı olarak kalır).
    if (targetGender != null) {
      final own = currentUserId != null ? 'id.eq.$currentUserId,' : '';
      query = query.or(
        '${own}and(gender.eq.$targetGender,age.gte.$minAge,age.lte.$maxAge)',
        referencedTable: 'owner',
      );
    }

    // 19.08 (Mustafa): gerçek kullanıcı kartları her zaman vitrin (test) kartlarının
    // ÜSTÜNDE — feed_rank 0=gerçek, 1=vitrin (DB trigger doldurur); grup içinde yeni→eski.
    // 22.08: limit yerine SAYFALI aralık — kullanıcı kaydırdıkça pencere
    // büyür, kart sayısı ne olursa olsun (influencer senaryosu) hepsi
    // ulaşılabilir. id = üçüncü sıralama anahtarı: sayfalar arası kararlı
    // sıra (created_at çakışsa bile kayma/duplikat olmaz).
    final requested = pageCount * feedPageSize;
    final data = await query
        .order('feed_rank', ascending: true)
        .order('created_at', ascending: false)
        .order('id', ascending: true)
        .range(0, requested - 1);

    final rows = data as List;
    // Aralık tamamen dolduysa sunucuda devamı olabilir.
    ref.read(feedHasMoreProvider(filter).notifier).state =
        rows.length >= requested;

    // 03.09: avatar yığını için başvuran fotoğrafları — ilan başına ilk 4 pending
    // başvuranın ilk (selfie olmayan) fotoğrafı, tüm feed için TEK sorgu.
    final wantedApplicantIds = <String>{};
    for (final row in rows) {
      final apps = ((row['applications'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>();
      for (final a in apps.where((a) => a['status'] == 'pending').take(4)) {
        final id = a['applicant_id'] as String?;
        if (id != null) wantedApplicantIds.add(id);
      }
    }
    final applicantPhoto = <String, String>{};
    if (wantedApplicantIds.isNotEmpty) {
      try {
        final ph = await client
            .from('user_photos')
            .select('user_id, url, order_index')
            .eq('is_selfie', false)
            .inFilter('user_id', wantedApplicantIds.toList())
            .order('order_index', ascending: true);
        for (final p in (ph as List).cast<Map<String, dynamic>>()) {
          final uid = p['user_id'] as String?;
          final url = p['url'] as String?;
          if (uid != null && url != null) applicantPhoto.putIfAbsent(uid, () => url);
        }
      } catch (_) {
        // Avatar yığını süs; foto gelmezse kart yine çizilir.
      }
    }

    return rows.map((row) {
      // ── Owner ─────────────────────────────────────────────────────────────
      final ownerRow = row['owner'] as Map<String, dynamic>?;
      if (ownerRow?['is_deleted'] == true) return null;

      // Yaş aralığı tercihi (product-logic §5): aralık dışı ilan sahibini gösterme
      final ownerAge = ownerRow?['age'] as int?;
      if (ownerAge != null && (ownerAge < minAge || ownerAge > maxAge)) {
        return null;
      }

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
        ..sort((a, b) =>
            (a['order_index'] as int? ?? 99)
                .compareTo(b['order_index'] as int? ?? 99));
      final ownerPhotoUrl = sortedPhotos.firstOrNull?['url'] as String?;

      // ── Applicant photos (up to 4 pending applicants) ─────────────────────
      // Hafif embed (status, applicant_id) → kural/sayaç için beklenen biçim
      // {'status', 'applicant': {'id'}} (feed_visibility_rules sözleşmesi).
      final apps = ((row['applications'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((a) => <String, dynamic>{
                'status': a['status'],
                'applicant': {'id': a['applicant_id']},
              })
          .toList();

      // 11.08 (Mustafa bulgusu): KABUL edilmiş başvuran kartı feed'de tekrar
      // görmez — "Хочу прийти" ölü mekanikti (§13), ilişki Mesajlar'a taşındı.
      // İlan diğer kullanıcılara görünmeye devam eder. pending/selected/
      // rejected kartı GÖRMEYE DEVAM EDER (rejected'ı gizlemek sessizlik
      // ilkesini deler). Kural tek kaynakta: feed_visibility_rules.dart.
      if (hideInvitationFromViewer(
        applications: apps.cast<Map<String, dynamic>>(),
        viewerId: currentUserId,
        ownerId: row['owner_id'] as String?,
      )) {
        return null;
      }
      final pendingApps = apps
          .cast<Map<String, dynamic>>()
          .where((a) => a['status'] == 'pending')
          .toList();

      final applicantPhotoUrls = pendingApps
          .take(4)
          .map((a) => applicantPhoto[
              (a['applicant'] as Map<String, dynamic>?)?['id'] as String? ?? ''])
          .whereType<String>()
          .toList();

      final cityRow = row['city'] as Map<String, dynamic>?;

      final appliedByMe = currentUserId != null &&
          pendingApps.any((a) =>
              (a['applicant'] as Map<String, dynamic>?)?['id'] ==
              currentUserId);

      return InvitationModel.fromJson({...row, 'owner': null, 'city': null}).copyWith(
        owner: owner,
        ownerPhotoUrl: ownerPhotoUrl,
        applicationCount: pendingApps.length,
        applicantPhotoUrls: applicantPhotoUrls,
        cityName: _cityName(cityRow, lang),
        appliedByMe: appliedByMe,
      );
    }).whereType<InvitationModel>()
        .where((inv) => inv.ownerPhotoUrl != null)
        // Sadece karşı cinsiyet (kendi kartların her zaman görünür)
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
