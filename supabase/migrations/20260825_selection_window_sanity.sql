-- 25.08.2026 — Seçim penceresi mantık düzeltmesi (Mustafa kararı, 24-25.08 vakaları)
--
-- Vaka 1 (Mustafa gift kartı): süre doldu, 0 başvuru — kart yine de 48 saat
--   'selecting'te bekledi. Seçilecek bir şey yokken pencere anlamsız.
-- Vaka 2 (Natalya walk kartı): başvuru zaten kabul edilmişti ve etkinlik geçmişti;
--   pencere yine de etkinlikten 38 saat sonrasına kadar açık kaldı.
--
-- Yeni kurallar (YALNIZ gerçek kullanıcı kartları; users.is_test_user = true
-- kartlar ESKİ davranışta kalır — canlılık motoru ritmi ve Apple demo sahnesi
-- etkilenmesin):
--   1) Süre dolduğunda seçilecek bir şey yoksa (bekleyen başvuru yok VEYA kabul
--      zaten yapılmış VEYA etkinlik saati geçmiş) kart 'selecting'e girmeden
--      doğrudan 'closed' olur.
--   2) Seçim penceresi etkinlik saatini aşamaz:
--      selection_deadline = least(expires_at + 48 saat, event_date).
--   3) 'selecting' sırasında koşullar oluşursa (kabul yapıldı / bekleyen kalmadı /
--      etkinlik geçti) kart bir sonraki saatlik koşuda kapanır.
--
-- Rollback: /root/backups/cronjobs_1_2_pre_selectionfix_20260825.txt içindeki
-- eski komutlarla cron.alter_job(1|2, command => ...) geri yüklenir.

select cron.alter_job(1, command => $cmd$
    -- 1a) Gerçek kullanıcı: seçilecek bir şey yoksa doğrudan kapan (25.08 kuralı)
    UPDATE invitations i
    SET status = 'closed'
    WHERE i.status = 'active'
      AND i.expires_at < NOW()
      AND NOT EXISTS (SELECT 1 FROM public.users u
                       WHERE u.id = i.owner_id AND u.is_test_user)
      AND (
        EXISTS (SELECT 1 FROM applications a
                 WHERE a.invitation_id = i.id AND a.status = 'accepted')
        OR NOT EXISTS (SELECT 1 FROM applications a
                        WHERE a.invitation_id = i.id AND a.status = 'pending')
        OR COALESCE(i.event_date, 'infinity'::timestamptz) <= NOW()
      );

    -- 1b) Kalanlar seçim penceresine; pencere etkinlik saatini aşamaz
    --     (test kartlarında eski kural: expires + 48 saat)
    UPDATE invitations i
    SET status = 'selecting',
        selection_deadline = CASE
          WHEN EXISTS (SELECT 1 FROM public.users u
                        WHERE u.id = i.owner_id AND u.is_test_user)
            THEN i.expires_at + interval '48 hours'
          ELSE LEAST(i.expires_at + interval '48 hours',
                     COALESCE(i.event_date, i.expires_at + interval '48 hours'))
        END
    WHERE i.status = 'active'
      AND i.expires_at < NOW();
  $cmd$);

select cron.alter_job(2, command => $cmd$
    UPDATE invitations i
    SET status = 'closed'
    WHERE i.status = 'selecting'
      AND (
        i.selection_deadline < NOW()
        OR (
          NOT EXISTS (SELECT 1 FROM public.users u
                       WHERE u.id = i.owner_id AND u.is_test_user)
          AND (
            (i.event_date IS NOT NULL AND i.event_date < NOW())
            OR EXISTS (SELECT 1 FROM applications a
                        WHERE a.invitation_id = i.id AND a.status = 'accepted')
            OR NOT EXISTS (SELECT 1 FROM applications a
                            WHERE a.invitation_id = i.id AND a.status = 'pending')
          )
        )
      );
  $cmd$);

-- Geriye dönük tek seferlik geçiş: mevcut 'selecting' gerçek-kullanıcı kartlarına
-- yeni kural hemen uygulanır (24.08'in iki takılı kartı burada kapanır).
UPDATE invitations i
SET status = 'closed'
WHERE i.status = 'selecting'
  AND NOT EXISTS (SELECT 1 FROM public.users u
                   WHERE u.id = i.owner_id AND u.is_test_user)
  AND (
    (i.event_date IS NOT NULL AND i.event_date < NOW())
    OR EXISTS (SELECT 1 FROM applications a
                WHERE a.invitation_id = i.id AND a.status = 'accepted')
    OR NOT EXISTS (SELECT 1 FROM applications a
                    WHERE a.invitation_id = i.id AND a.status = 'pending')
  );
