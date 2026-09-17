/// iOS «açık akış» (17.09.2026): kart sırasını sahibin cinsiyetine göre
/// DÖNÜŞÜMLÜ dizer (E, K, E, K …). SAF mantık — Supabase'e dokunmaz.
///
/// Neden: filtre kalkınca sunucu sırası (created_at) ya da Keşfet'in rastgele
/// karıştırması şans eseri aynı cinsiyeti art arda öne düşürebiliyor; Apple
/// inceleyicisinin ilk ekranı karışık olmalı. Grupların KENDİ içindeki sıra
/// korunur; bir grup biterse diğeri olduğu gibi devam eder. Cinsiyeti
/// bilinmeyenler (null/boş) kendi grubu olarak dönüşüme katılır.
/// [pinFirst] true dönen kartlar (kendi kartım) sıraya girmeden en başta kalır.
List<T> interleaveByGender<T>(
  List<T> items,
  String? Function(T item) genderOf, {
  bool Function(T item)? pinFirst,
}) {
  final pinned = <T>[];
  final groups = <String, List<T>>{};
  final order = <String>[];
  for (final it in items) {
    if (pinFirst != null && pinFirst(it)) {
      pinned.add(it);
      continue;
    }
    final g = genderOf(it) ?? '';
    if (!groups.containsKey(g)) {
      groups[g] = <T>[];
      order.add(g);
    }
    groups[g]!.add(it);
  }
  final out = <T>[...pinned];
  var remaining = groups.values.fold<int>(0, (n, l) => n + l.length);
  final idx = {for (final g in order) g: 0};
  while (remaining > 0) {
    for (final g in order) {
      final list = groups[g]!;
      final i = idx[g]!;
      if (i < list.length) {
        out.add(list[i]);
        idx[g] = i + 1;
        remaining--;
      }
    }
  }
  return out;
}
