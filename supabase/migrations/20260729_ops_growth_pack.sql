-- Ops büyüme paketi (29.07): kayıt hunisi + audit erişimi + selfie alarmı
-- artık buton taşıyan kanala gider (Telegram inline onay, agent köprüsü).

-- Kayıt hunisi (yalnız gerçek kullanıcılar)
CREATE OR REPLACE VIEW public.v_funnel AS
SELECT
  (SELECT count(*)::int FROM users
    WHERE NOT is_test_user AND NOT is_deleted) AS registered,
  (SELECT count(*)::int FROM users
    WHERE NOT is_test_user AND NOT is_deleted
      AND selfie_status = 'approved') AS selfie_approved,
  (SELECT count(DISTINCT a.applicant_id)::int FROM applications a
    JOIN users u ON u.id = a.applicant_id
    WHERE NOT u.is_test_user) AS applied,
  (SELECT count(DISTINCT x.uid)::int
     FROM (SELECT user1_id AS uid FROM matches
           UNION SELECT user2_id FROM matches) x
     JOIN users u ON u.id = x.uid
    WHERE NOT u.is_test_user) AS matched;

GRANT SELECT ON public.v_funnel TO ops_moderator;
GRANT SELECT ON public.audit_log TO ops_moderator;

-- Selfie alarmı: düz metin yerine 'ops_selfie' kanalı (payload: uid|isim) —
-- agent bunu Telegram'a ✅ Onayla butonlu mesaj olarak gönderir.
CREATE OR REPLACE FUNCTION ops.trg_tg_new_selfie() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ops, public AS $$
DECLARE uname text;
BEGIN
  IF NEW.is_selfie AND COALESCE(NEW.moderation_status, '') = 'pending' THEN
    SELECT name INTO uname FROM public.users WHERE id = NEW.user_id;
    PERFORM pg_notify('ops_selfie',
      NEW.user_id::text || '|' || COALESCE(uname, ''));
  END IF;
  RETURN NEW;
END $$;
