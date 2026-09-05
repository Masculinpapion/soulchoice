// 05.09 — FEED DELTA SAYFALAMA: 22.08 sonsuz kaydırmanın son hâli.
// 22.08 tasarımı her yeni dilimde 0..N aralığını baştan çekiyordu (N sayfa =
// N×120 satır); kart sayısı binleri bulunca (reklam günü) maliyet kareselleşir.
// Artık her dilim yalnız KENDİ 120 satırını çeker: imleç = bir önceki dilimin
// son satırı, sorgu «bu satırdan sonrası». Sıralama invitations_provider ile
// birebir: feed_rank ASC, created_at DESC, id ASC. Bu modül saf Dart'tır
// (Supabase yok) → test/logic/feed_keyset_test.dart.

/// Bir dilimin son satırından türeyen imleç. Üç alan birlikte sırayı tek
/// anlamlı yapar (created_at çakışsa bile id ayırır).
typedef FeedCursor = ({int feedRank, String createdAt, String id});

/// PostgREST satırından imleç. Alanlardan biri eksik/yanlış tipteyse null →
/// çağıran «devamı yok» sayar (asla yanlış aralık çekmez).
FeedCursor? feedCursorFromRow(Map<String, dynamic> row) {
  final rank = row['feed_rank'];
  final created = row['created_at'];
  final id = row['id'];
  if (rank is! int || created is! String || id is! String) return null;
  if (created.isEmpty || id.isEmpty) return null;
  return (feedRank: rank, createdAt: created, id: id);
}

/// PostgREST `or=` ifadesi: (rank, created_at DESC, id) sırasında imleçten
/// SONRAKİ satırlar. Değerler çift tırnakta — zaman damgası ':' '+' '.'
/// taşır, tırnaksız değerde PostgREST '.'/','/parantezi ayraç sayabilir.
String feedKeysetAfter(FeedCursor c) {
  final r = c.feedRank;
  final t = '"${c.createdAt}"';
  final i = '"${c.id}"';
  return 'feed_rank.gt.$r,'
      'and(feed_rank.eq.$r,created_at.lt.$t),'
      'and(feed_rank.eq.$r,created_at.eq.$t,id.gt.$i)';
}
