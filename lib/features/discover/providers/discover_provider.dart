import 'dart:math';

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

/// 22.08 — SONSUZ KAYDIRMA (feed ile aynı ilke, bkz. invitations_provider):
/// tek istekte inen dilim boyutu; ızgara sona yaklaşınca sayfa artırılır.
const discoverPageSize = 100;

/// Şehir başına yüklü sayfa sayısı (autoDispose: ekran kapanınca sıfırlanır).
final discoverPageCountProvider =
    StateProvider.autoDispose.family<int, String?>((ref, _) => 1);

/// Sunucuda daha kart var mı? (istenen aralık tamamen dolduysa true)
final discoverHasMoreProvider =
    StateProvider.autoDispose.family<bool, String?>((ref, _) => true);

/// Teslim edilmiş kart SIRASI (invitation id) — sayfa eklenince önceki
/// kartlar YERİNDE kalsın, yeniler karıştırılıp SONA eklensin diye
/// oturum boyunca hatırlanır (ızgara kullanıcının altında yeniden dizilmez).
final Map<String?, List<String>> _discoverOrderMemo = {};

final discoverProvider =
    FutureProvider.autoDispose.family<List<InvitationModel>, String?>((ref, cityId) async {
  final currentUserId = ref.read(currentUserIdProvider);
  final lang = ref.watch(localeProvider)?.languageCode;
  final pageCount = ref.watch(discoverPageCountProvider(cityId));
  final client = Supabase.instance.client;

  // Fetch current user gender + blocked IDs (sadece karşı cinsiyet gösterilir)
  List<String> blockedIds = [];
  String? myGender;
  String? targetGender;
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
    targetGender = myGender == 'male' ? 'female' : myGender == 'female' ? 'male' : null;
    minAge = userRow?['min_age'] as int? ?? 21;
    maxAge = userRow?['max_age'] as int? ?? 60;
  }

  // Tek sorgu iskeleti — şehir kısıtı parametreyle. Kararlı sıralama
  // (feed_rank, created_at, id) = sayfalar arası kayma/duplikat olmaz.
  Future<List<Map<String, dynamic>>> fetchRows(
      {String? onlyCity, bool excludeSelected = false, required int limit}) async {
    if (limit <= 0) return const [];
    var query = client.from('invitations').select(
          '*, '
          'city:cities(name, name_ru, name_tr, name_en), '
          // 20.08: !inner → karşı cins + yaş filtresi sunucuda (bkz. invitations_provider)
          'owner:users!inner(id, name, age, gender, subscription_status, is_deleted, '
          'photos:user_photos(url, is_primary, is_selfie, order_index)), '
          // RLS: başkasının kartında yalnız KENDİ başvurum döner (11.08)
          'applications(status, applicant_id)',
        );

    query = query
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());

    if (onlyCity != null) query = query.eq('city_id', onlyCity);
    if (excludeSelected && cityId != null) query = query.neq('city_id', cityId!);
    if (currentUserId != null) {
      query = query.neq('owner_id', currentUserId);
    }
    if (blockedIds.isNotEmpty) {
      query = query.not('owner_id', 'in', '(${blockedIds.join(',')})');
    }
    if (targetGender != null) {
      query = query
          .eq('owner.gender', targetGender!)
          .gte('owner.age', minAge)
          .lte('owner.age', maxAge);
    }

    // 19.08 (Mustafa): gerçek kartlar vitrinin üstünde (feed_rank), sonra yeni→eski.
    final data = await query
        .order('feed_rank', ascending: true)
        .order('created_at', ascending: false)
        .order('id', ascending: true)
        .range(0, limit - 1);
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ŞEHİR ÖNCELİĞİ (Mustafa 22.08): önce kullanıcının seçili şehri TAMAMEN
  // tüketilir, diğer şehirler ancak ondan sonra akmaya başlar.
  final requested = pageCount * discoverPageSize;
  List<Map<String, dynamic>> cityRows = const [];
  List<Map<String, dynamic>> otherRows = const [];
  if (cityId != null) {
    cityRows = await fetchRows(onlyCity: cityId, limit: requested);
    otherRows = await fetchRows(
        excludeSelected: true, limit: requested - cityRows.length);
  } else {
    otherRows = await fetchRows(limit: requested);
  }
  ref.read(discoverHasMoreProvider(cityId).notifier).state =
      cityRows.length + otherRows.length >= requested;

  // Sıra koruması: memo'daki kartlar bilinen sırayla önce, İLK KEZ gelenler
  // grup içinde (şehir → diğer) karıştırılıp sona. Böylece sayfa eklenince
  // ızgara mevcut düzenini korur, çeşitlilik ilk yüklemede sağlanır.
  final byId = {for (final r in [...cityRows, ...otherRows]) r['id'] as String: r};
  final cityIds = {for (final r in cityRows) r['id'] as String};
  final known = <Map<String, dynamic>>[];
  for (final id in _discoverOrderMemo[cityId] ?? const <String>[]) {
    final r = byId.remove(id);
    if (r != null) known.add(r);
  }
  final fresh = byId.values.toList();
  final freshCity = fresh.where((r) => cityIds.contains(r['id'])).toList()
    ..shuffle(Random());
  final freshOther = fresh.where((r) => !cityIds.contains(r['id'])).toList()
    ..shuffle(Random());
  final rows = [...known, ...freshCity, ...freshOther];
  _discoverOrderMemo[cityId] = [for (final r in rows) r['id'] as String];

  final list = rows.map((row) {
    final ownerRow = row['owner'] as Map<String, dynamic>?;
    if (ownerRow?['is_deleted'] == true) return null;

    // 11.08 (feed'le aynı kural, product-logic §6): kabul edilmiş başvuran
    // ilanı Keşfet'te de görmez — ilişki Mesajlar'a taşındı.
    final apps = (row['applications'] as List<dynamic>?) ?? const [];
    final acceptedByMe = currentUserId != null &&
        apps.cast<Map<String, dynamic>>().any((a) =>
            a['status'] == 'accepted' && a['applicant_id'] == currentUserId);
    if (acceptedByMe) return null;

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

  // Kullanıcı başına 1 kart — aynı kişinin birden fazla daveti olsa bile
  final seen = <String>{};
  return list.where((inv) => inv.owner?.id != null && seen.add(inv.owner!.id)).toList();
});
