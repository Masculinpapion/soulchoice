-- Favori (yıldız) özelliği ÜRÜN KARARIYLA kaldırıldı (13.07.2026, Mustafa):
-- kart akışında karar net (başvur/geç), Instagram-vari biriktirme konsepte
-- yabancı; toplanan favorilerin gösterildiği bir ekran da hiç olmadı.
-- Not: tablo prod'a ancak 13.07'de (repo-prod drift tespitiyle) uygulanmıştı,
-- aynı gün kaldırıldı; gerçek kullanıcı verisi yok.
DROP TABLE IF EXISTS favorites;
