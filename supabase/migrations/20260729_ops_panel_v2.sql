-- Ops panel v2 veri katmanı (29.07.2026, madde 10d/10e)
-- İlan moderasyonu listesi + kullanıcı detay RPC'si (ops_moderator erişimi).

-- 10e: aktif ilanlar (moderasyon gözü) — sahibin adı + birincil fotosu dahil
CREATE OR REPLACE VIEW public.v_active_invitations AS
SELECT i.id,
       i.title,
       i.description,
       i.category,
       i.flow_type,
       i.venue_name,
       i.event_date,
       i.created_at,
       i.expires_at,
       u.id   AS owner_id,
       u.name AS owner_name,
       u.age  AS owner_age,
       u.is_test_user,
       (SELECT p.url FROM public.user_photos p
         WHERE p.user_id = u.id AND p.is_selfie = false
         ORDER BY p.is_primary DESC, p.order_index LIMIT 1) AS owner_photo_url,
       (SELECT count(*)::int FROM public.applications a
         WHERE a.invitation_id = i.id AND a.status = 'pending') AS pending_applications
FROM public.invitations i
JOIN public.users u ON u.id = i.owner_id
WHERE i.status = 'active' AND i.expires_at > now()
ORDER BY i.created_at DESC;

GRANT SELECT ON public.v_active_invitations TO ops_moderator;

-- 10d: kullanıcı detayı (panelde profil incelemesi)
CREATE OR REPLACE FUNCTION public.ops_user_detail(p_user_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'user', (SELECT jsonb_build_object(
        'id', u.id, 'name', u.name, 'age', u.age, 'gender', u.gender,
        'bio', u.bio,
        'city', (SELECT c.name FROM cities c WHERE c.id = u.city_id),
        'phone', (SELECT au.phone FROM auth.users au WHERE au.id = p_user_id),
        'billing_email', u.billing_email,
        'selfie_status', u.selfie_status,
        'subscription_status', u.subscription_status,
        'premium_until', u.premium_until,
        'free_application_used', u.free_application_used,
        'is_test_user', u.is_test_user,
        'banned', COALESCE(u.banned, false),
        'suspended_at', u.suspended_at,
        'verified', u.verified,
        'created_at', u.created_at,
        'locale', u.locale
      ) FROM users u WHERE u.id = p_user_id),
    -- Yalnız profil fotoları: selfie'ler private bucket'ta, ham URL panelde
    -- açılmaz (29.07 bulgusu) — güncel selfie agent'ın selfie-photo ucundan gelir.
    'photos', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'url', p.url, 'is_primary', p.is_primary,
        'moderation_status', p.moderation_status)
        ORDER BY p.is_primary DESC, p.order_index)
      FROM user_photos p WHERE p.user_id = p_user_id AND p.is_selfie = false), '[]'::jsonb),
    'counters', jsonb_build_object(
      'active_invitations', (SELECT count(*)::int FROM invitations i
        WHERE i.owner_id = p_user_id AND i.status = 'active' AND i.expires_at > now()),
      'total_invitations', (SELECT count(*)::int FROM invitations i
        WHERE i.owner_id = p_user_id),
      'applications_sent', (SELECT count(*)::int FROM applications a
        WHERE a.applicant_id = p_user_id),
      'matches', (SELECT count(*)::int FROM matches m
        WHERE m.user1_id = p_user_id OR m.user2_id = p_user_id),
      'reports_against', (SELECT count(*)::int FROM reports r
        WHERE r.reported_user_id = p_user_id),
      'payments_paid', (SELECT count(*)::int FROM payments pay
        WHERE pay.user_id = p_user_id AND pay.status = 'paid')
    )
  );
$$;

REVOKE ALL ON FUNCTION public.ops_user_detail(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ops_user_detail(uuid) TO ops_moderator;
