select cron.schedule('cleanup-call-otps', '55 3 * * *', $cron$delete from public.call_otps where expires_at < now() - interval '1 day'$cron$);
select cron.schedule('cleanup-client-errors', '15 3 * * *', $cron$select public.cleanup_client_errors()$cron$);
select cron.schedule('cleanup-closed-invitations', '5 * * * *', $cron$select public.cleanup_closed_invitations()$cron$);
select cron.schedule('cleanup-invitation-create-log', '40 3 * * *', $cron$delete from public.invitation_create_log where created_at < now() - interval '30 days'$cron$);
select cron.schedule('cleanup-messages-archive', '35 3 * * *', $cron$delete from public.messages_archive where archived_at < now() - interval '90 days'$cron$);
select cron.schedule('cleanup-notifications', '50 3 * * *', $cron$delete from public.notifications where read_at is not null and created_at < now() - interval '90 days'$cron$);
select cron.schedule('cleanup-otp-send-log', '45 3 * * *', $cron$delete from public.otp_send_log where created_at < now() - interval '2 days'$cron$);
select cron.schedule('downgrade-expired-premium', '25 * * * *', $cron$select downgrade_expired_premium()$cron$);
select cron.schedule('invitation-active-to-selecting', '0 * * * *', $cron$
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
  $cron$);
select cron.schedule('invitation-selecting-to-closed', '0 * * * *', $cron$
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
  $cron$);
select cron.schedule('simulate-test-liveliness', '7,22,37,52 * * * *', $cron$select public.simulate_test_liveliness();$cron$);
