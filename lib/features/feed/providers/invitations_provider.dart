import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/invitation_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../logic/feed_keyset.dart';
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
/// listenin sonuna yaklaşınca [feedPageCountProvider] artırılır.
/// 05.09 — DELTA: eskiden her artışta 0..(sayfa×boyut) baştan çekiliyordu;
/// artık yalnız yeni dilim iner (imleç: önceki dilimin son satırı, bkz.
/// feed_keyset.dart). Dilim sayısı ne olursa olsun istek başına ≤120 satır.
const feedPageSize = 120;

/// Filter başına yüklü sayfa sayısı. autoDispose: sekme/filtre değişince sıfırlanır.
final feedPageCountProvider =
    StateProvider.autoDispose.family<int, _InvitationFilter>((ref, _) => 1);

/// Sunucuda daha kart var mı? (son inen dilim tamamen dolduysa true)
final feedHasMoreProvider =
    StateProvider.autoDispose.family<bool, _InvitationFilter>((ref, _) => true);

/// Feed'i baştan tazele — `ref.invalidate(invitationsProvider)`'ın yerini
/// alır (05.09). Yalnız BAŞ dilimler yeniden çekilir; sonraki dilimler ancak
/// bir öncekinin imleci (son satırı) değişirse peşinden gelir. 30 sn'lik
/// zamanlayıcı, ilan oluşturma/düzenleme, profil/ayar değişikliği, pull-to-
/// refresh — hepsi buradan geçer; provider zincirini dışarıdan bilmek gerekmez.
extension FeedRefresh on WidgetRef {
  void refreshFeed() {
    invalidate(_feedViewerProvider);
    invalidate(_feedHeadProvider);
    invalidate(invitationsProvider);
  }
}

/// İzleyici bağlamı: engel listesi + cinsiyet/yaş tercihi. Dilim başına
/// değil, feed başına bir kez çekilir; refreshFeed ile tazelenir.
class _FeedViewer {
  final String? userId;
  final List<String> blockedIds;
  final String? gender;
  final int minAge;
  final int maxAge;
  const _FeedViewer({
    required this.userId,
    required this.blockedIds,
    required this.gender,
    required this.minAge,
    required this.maxAge,
  });

  String? get targetGender =>
      gender == 'male' ? 'female' : gender == 'female' ? 'male' : null;

  /// Sonraki dilimlerin selectAsync anahtarı: bağlam gerçekten değişmedikçe
  /// (yeni engel, yaş aralığı) dilimler yeniden çekilmez.
  String get key =>
      '$userId|$gender|$minAge|$maxAge|${(List.of(blockedIds)..sort()).join(',')}';
}

final _feedViewerProvider = FutureProvider.autoDispose<_FeedViewer>((ref) async {
  final client = Supabase.instance.client;
  final currentUserId = ref.read(currentUserIdProvider);
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
  return _FeedViewer(
    userId: currentUserId,
    blockedIds: blockedIds,
    gender: myGender,
    minAge: minAge,
    maxAge: maxAge,
  );
});

/// Sunucudan inen bir dilim: ham satırlar + sıradaki dilimin imleci
/// (null = devamı yok: dilim dolmadı ya da son satırdan imleç türemedi).
class _FeedPage {
  final List<Map<String, dynamic>> rows;
  final FeedCursor? next;
  const _FeedPage(this.rows, this.next);
  static const empty = _FeedPage([], null);
}

Future<_FeedPage> _fetchFeedPage(
  _InvitationFilter filter,
  _FeedViewer viewer, {
  FeedCursor? after,
}) async {
  final client = Supabase.instance.client;
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
  if (viewer.blockedIds.isNotEmpty) {
    query = query.not('owner_id', 'in', '(${viewer.blockedIds.join(',')})');
  }
  // 20.08: sunucu tarafı sahip filtresi — kendi kartım her zaman, diğerleri
  // karşı cins + yaş aralığı (istemci filtresi güvenlik ağı olarak kalır).
  final targetGender = viewer.targetGender;
  if (targetGender != null) {
    final own = viewer.userId != null ? 'id.eq.${viewer.userId},' : '';
    query = query.or(
      '${own}and(gender.eq.$targetGender,age.gte.${viewer.minAge},age.lte.${viewer.maxAge})',
      referencedTable: 'owner',
    );
  }
  // 05.09 DELTA: imleçten sonrası (sıralamayla birebir, feed_keyset.dart).
  if (after != null) {
    query = query.or(feedKeysetAfter(after));
  }

  // 19.08 (Mustafa): gerçek kullanıcı kartları her zaman vitrin (test) kartlarının
  // ÜSTÜNDE — feed_rank 0=gerçek, 1=vitrin (DB trigger doldurur); grup içinde yeni→eski.
  // id = üçüncü sıralama anahtarı: dilimler arası kararlı sıra (created_at
  // çakışsa bile kayma/duplikat olmaz). Sıralama değişirse feed_keyset.dart da değişir.
  final data = await query
      .order('feed_rank', ascending: true)
      .order('created_at', ascending: false)
      .order('id', ascending: true)
      .limit(feedPageSize);

  final rows = (data as List).cast<Map<String, dynamic>>();
  // Dilim tamamen dolduysa sunucuda devamı olabilir → son satır imleç olur.
  final next = rows.length >= feedPageSize ? feedCursorFromRow(rows.last) : null;
  return _FeedPage(rows, next);
}

/// Baş dilim (0..119). refreshFeed bunu tazeler; sonraki dilimler yalnız
/// imleç değişirse peşinden yeniden iner.
final _feedHeadProvider =
    FutureProvider.autoDispose.family<_FeedPage, _InvitationFilter>((ref, filter) async {
  final viewer = await ref.watch(_feedViewerProvider.future);
  return _fetchFeedPage(filter, viewer);
});

/// i ≥ 1 dilimi: (i-1). dilimin imlecinden sonrası. Önceki dilimin imleci
/// null ise (devamı yok) istek atmadan boş döner.
// Açık tip: sağlayıcı kendini (index-1) çağırır, çıkarım döngüye girer.
final AutoDisposeFutureProviderFamily<_FeedPage, (_InvitationFilter, int)>
    _feedNextPageProvider = FutureProvider.autoDispose
        .family<_FeedPage, (_InvitationFilter, int)>((ref, key) async {
  final (filter, index) = key;
  final prev = index <= 1
      ? _feedHeadProvider(filter)
      : _feedNextPageProvider((filter, index - 1));
  // İki bağımlılık da await'ten ÖNCE izlenir (Riverpod: async boşluk sonrası
  // watch'tan kaçın). Bağlam anahtarı değişmedikçe bu dilim yeniden inmez.
  final afterFuture = ref.watch(prev.selectAsync((p) => p.next));
  final viewerKeyFuture =
      ref.watch(_feedViewerProvider.selectAsync((v) => v.key));
  final after = await afterFuture;
  await viewerKeyFuture;
  if (after == null) return _FeedPage.empty;
  final viewer = await ref.read(_feedViewerProvider.future);
  return _fetchFeedPage(filter, viewer, after: after);
});

final invitationsProvider = FutureProvider.autoDispose.family<List<InvitationModel>, _InvitationFilter>(
  (ref, filter) async {
    final client = Supabase.instance.client;
    final pageCount = ref.watch(feedPageCountProvider(filter));
    final currentUserId = ref.read(currentUserIdProvider);
    final lang = ref.watch(localeProvider)?.languageCode;

    // Dilimler zincir hâlinde (i, i-1'in imlecini bekler); hepsi izlenir ki
    // herhangi biri değişince liste yeniden kurulsun.
    final pageFutures = <Future<_FeedPage>>[
      ref.watch(_feedHeadProvider(filter).future),
      for (var i = 1; i < pageCount; i++)
        ref.watch(_feedNextPageProvider((filter, i)).future),
    ];
    final viewer = await ref.watch(_feedViewerProvider.future);
    final pages = await Future.wait(pageFutures);

    final targetGender = viewer.targetGender;
    final minAge = viewer.minAge;
    final maxAge = viewer.maxAge;

    // Dilimleri birleştir; id ile kopya koruması (dilimler arasında rebirth /
    // yeni kart girse bile aynı ilan iki kez çizilmez).
    final seenIds = <String>{};
    final rows = <Map<String, dynamic>>[];
    for (final page in pages) {
      for (final row in page.rows) {
        final id = row['id'] as String?;
        if (id != null && !seenIds.add(id)) continue;
        rows.add(row);
      }
    }
    // Son inen dilimin imleci varsa sunucuda devamı olabilir.
    ref.read(feedHasMoreProvider(filter).notifier).state =
        pages.isNotEmpty && pages.last.next != null;

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
