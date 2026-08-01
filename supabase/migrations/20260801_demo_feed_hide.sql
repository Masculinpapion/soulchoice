-- 01.08.2026 — Mağaza demo hesabının davetiyeleri gerçek kullanıcı feed'ine çıkmasın
-- Vaka: Google Play inceleme robotu demo hesapla (+70000000001) girip "Coffee and
-- Chat" davetiyesi oluşturdu; kart 24 saat boyunca Moskova feed'inde herkese
-- göründü. Apple incelemesi de aynısını yapabilir.
-- Çözüm: demo hesabın active kartları yalnız kendisine görünür (denetçi kendi
-- kartını görmeye devam eder — inceleme deneyimi bozulmaz).
-- Demo hesap uuid'i sabittir (15.07.2026'da oluşturuldu, store review notlarında).
-- Eski tanım (geri dönüş): ((status = 'active') OR (owner_id = auth.uid()))
ALTER POLICY invitations_select ON public.invitations
USING (((status = 'active' AND owner_id <> '385ea0eb-2089-4fd2-8883-8a47a39da29a'::uuid)
        OR (owner_id = auth.uid())));
