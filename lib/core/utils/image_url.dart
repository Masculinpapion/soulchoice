/// 16.10.2026: Kart/avatar görselleri için küçültülmüş sürüm.
///
/// Supabase Storage'ın görsel dönüştürme ucu (`/render/image/public/…?width=`)
/// sunucuda çalışıyor; orijinal 1600 px / ~900 KB fotoğraf yerine istenen
/// genişlikte JPEG döner (600 px ≈ 40 KB). Storage dışı veya zaten dönüştürülmüş
/// adresler olduğu gibi döner. Dosya adları benzersiz olduğu için nginx/CDN
/// önbelleği güvenli.
String thumb(String url, int width, {int quality = 75}) {
  const objectPath = '/storage/v1/object/public/';
  const renderPath = '/storage/v1/render/image/public/';
  if (!url.contains(objectPath) || url.contains(renderPath)) return url;
  final base = url.replaceFirst(objectPath, renderPath);
  final sep = base.contains('?') ? '&' : '?';
  return '$base${sep}width=$width&quality=$quality';
}
