-- 31.07 denetim backlog'u: repo, prod'un güvenilir kopyası değildi — RLS
-- politikaları migration zincirinde eksikti. Bu dosya prod'dan otomatik dökümdür
-- (pg_policies + pg_tables.rowsecurity, 31.07.2026 23:59). İdempotent:
-- drop policy if exists + create policy. Prod'a uygulanması no-op'tur;
-- sıfırdan kurulumda prod ile aynı RLS durumunu üretir.
-- NOT: politika değişikliği yaparken bu dosyayı DEĞİL, yeni migration yaz.
-- NOT: supabase_admin ile koşulmalı — tabloların çoğunun sahibi supabase_admin,
-- postgres rolü "must be owner" hatası alır (31.07 doğrulandı).

alter table public.applications enable row level security;
alter table public.audit_log enable row level security;
alter table public.billing_config enable row level security;
alter table public.billing_events enable row level security;
alter table public.blocks enable row level security;
alter table public.call_otps enable row level security;
alter table public.cities enable row level security;
alter table public.city_keys enable row level security;
alter table public.city_requests enable row level security;
alter table public.cron_heartbeat enable row level security;
alter table public.feature_flags enable row level security;
alter table public.internal_secrets enable row level security;
alter table public.invitation_gift_links enable row level security;
alter table public.invitations enable row level security;
alter table public.matches enable row level security;
alter table public.message_reactions enable row level security;
alter table public.messages enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;
alter table public.otp_codes enable row level security;
alter table public.payments enable row level security;
alter table public.places enable row level security;
alter table public.push_log enable row level security;
alter table public.reports enable row level security;
alter table public.subscriptions enable row level security;
alter table public.user_devices enable row level security;
alter table public.user_photos enable row level security;
alter table public.user_prompts enable row level security;
alter table public.user_stats enable row level security;
alter table public.users enable row level security;
drop policy if exists applications_insert on public.applications;
create policy applications_insert on public.applications
  as permissive for INSERT
  to public
  with check ((applicant_id = auth.uid()));

drop policy if exists applications_select on public.applications;
create policy applications_select on public.applications
  as permissive for SELECT
  to public
  using (((applicant_id = auth.uid()) OR (invitation_id IN ( SELECT invitations.id
   FROM invitations
  WHERE (invitations.owner_id = auth.uid())))));

drop policy if exists applications_update on public.applications;
create policy applications_update on public.applications
  as permissive for UPDATE
  to public
  using (((applicant_id = auth.uid()) OR (invitation_id IN ( SELECT invitations.id
   FROM invitations
  WHERE (invitations.owner_id = auth.uid())))))
  with check ((((applicant_id = auth.uid()) AND (status = ANY (ARRAY['withdrawn'::text, 'pending'::text]))) OR ((invitation_id IN ( SELECT invitations.id
   FROM invitations
  WHERE (invitations.owner_id = auth.uid()))) AND (status = ANY (ARRAY['accepted'::text, 'rejected'::text])))));

drop policy if exists audit_read on public.audit_log;
create policy audit_read on public.audit_log
  as permissive for SELECT
  to ops_moderator
  using (true);

drop policy if exists service_manage_billing_config on public.billing_config;
create policy service_manage_billing_config on public.billing_config
  as permissive for ALL
  to public
  using ((auth.role() = 'service_role'::text));

drop policy if exists service_manage_billing_events on public.billing_events;
create policy service_manage_billing_events on public.billing_events
  as permissive for ALL
  to public
  using ((auth.role() = 'service_role'::text));

drop policy if exists "Users manage own blocks" on public.blocks;
create policy "Users manage own blocks" on public.blocks
  as permissive for ALL
  to public
  using ((blocker_id = auth.uid()));

drop policy if exists blocks_insert on public.blocks;
create policy blocks_insert on public.blocks
  as permissive for INSERT
  to public
  with check ((blocker_id = auth.uid()));

drop policy if exists blocks_select on public.blocks;
create policy blocks_select on public.blocks
  as permissive for SELECT
  to public
  using ((blocker_id = auth.uid()));

drop policy if exists service_manage_call_otps on public.call_otps;
create policy service_manage_call_otps on public.call_otps
  as permissive for ALL
  to public
  using ((auth.role() = 'service_role'::text));

drop policy if exists cities_select on public.cities;
create policy cities_select on public.cities
  as permissive for SELECT
  to public
  using (true);

drop policy if exists city_keys_read on public.city_keys;
create policy city_keys_read on public.city_keys
  as permissive for SELECT
  to authenticated
  using (true);

drop policy if exists cr_insert on public.city_requests;
create policy cr_insert on public.city_requests
  as permissive for INSERT
  to public
  with check ((user_id = auth.uid()));

drop policy if exists cr_select_own on public.city_requests;
create policy cr_select_own on public.city_requests
  as permissive for SELECT
  to public
  using ((user_id = auth.uid()));

drop policy if exists service_manage_cron_heartbeat on public.cron_heartbeat;
create policy service_manage_cron_heartbeat on public.cron_heartbeat
  as permissive for ALL
  to public
  using ((auth.role() = 'service_role'::text));

drop policy if exists feature_flags_select on public.feature_flags;
create policy feature_flags_select on public.feature_flags
  as permissive for SELECT
  to authenticated
  using (true);

drop policy if exists gift_link_owner_write on public.invitation_gift_links;
create policy gift_link_owner_write on public.invitation_gift_links
  as permissive for ALL
  to public
  using ((invitation_id IN ( SELECT invitations.id
   FROM invitations
  WHERE (invitations.owner_id = auth.uid()))))
  with check ((invitation_id IN ( SELECT invitations.id
   FROM invitations
  WHERE (invitations.owner_id = auth.uid()))));

drop policy if exists invitations_delete on public.invitations;
create policy invitations_delete on public.invitations
  as permissive for DELETE
  to public
  using ((owner_id = auth.uid()));

drop policy if exists invitations_insert on public.invitations;
create policy invitations_insert on public.invitations
  as permissive for INSERT
  to public
  with check ((owner_id = auth.uid()));

drop policy if exists invitations_select on public.invitations;
create policy invitations_select on public.invitations
  as permissive for SELECT
  to public
  using (((status = 'active'::text) OR (owner_id = auth.uid())));

drop policy if exists invitations_update on public.invitations;
create policy invitations_update on public.invitations
  as permissive for UPDATE
  to public
  using ((owner_id = auth.uid()));

drop policy if exists matches_delete on public.matches;
create policy matches_delete on public.matches
  as permissive for DELETE
  to public
  using (((user1_id = auth.uid()) OR (user2_id = auth.uid())));

drop policy if exists matches_insert on public.matches;
create policy matches_insert on public.matches
  as permissive for INSERT
  to authenticated
  with check (((user1_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM invitations i
  WHERE ((i.id = matches.invitation_id) AND (i.owner_id = auth.uid())))) AND (EXISTS ( SELECT 1
   FROM applications a
  WHERE ((a.invitation_id = matches.invitation_id) AND (a.applicant_id = matches.user2_id) AND (a.status = ANY (ARRAY['pending'::text, 'selected'::text, 'accepted'::text])))))));

drop policy if exists matches_select on public.matches;
create policy matches_select on public.matches
  as permissive for SELECT
  to public
  using (((user1_id = auth.uid()) OR (user2_id = auth.uid())));

drop policy if exists matches_update on public.matches;
create policy matches_update on public.matches
  as permissive for UPDATE
  to public
  using (((user1_id = auth.uid()) OR (user2_id = auth.uid())));

drop policy if exists mr_delete on public.message_reactions;
create policy mr_delete on public.message_reactions
  as permissive for DELETE
  to public
  using ((user_id = auth.uid()));

drop policy if exists mr_insert on public.message_reactions;
create policy mr_insert on public.message_reactions
  as permissive for INSERT
  to public
  with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM matches m
  WHERE ((m.id = message_reactions.match_id) AND ((m.user1_id = auth.uid()) OR (m.user2_id = auth.uid())))))));

drop policy if exists mr_select on public.message_reactions;
create policy mr_select on public.message_reactions
  as permissive for SELECT
  to public
  using ((EXISTS ( SELECT 1
   FROM matches m
  WHERE ((m.id = message_reactions.match_id) AND ((m.user1_id = auth.uid()) OR (m.user2_id = auth.uid()))))));

drop policy if exists mr_update on public.message_reactions;
create policy mr_update on public.message_reactions
  as permissive for UPDATE
  to public
  using ((user_id = auth.uid()))
  with check ((user_id = auth.uid()));

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  as permissive for INSERT
  to public
  with check (((sender_id = auth.uid()) AND (match_id IN ( SELECT matches.id
   FROM matches
  WHERE (((matches.user1_id = auth.uid()) OR (matches.user2_id = auth.uid())) AND (matches.user1_id IS NOT NULL) AND (matches.user2_id IS NOT NULL))))));

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  as permissive for SELECT
  to public
  using ((match_id IN ( SELECT matches.id
   FROM matches
  WHERE ((matches.user1_id = auth.uid()) OR (matches.user2_id = auth.uid())))));

drop policy if exists messages_update_read on public.messages;
create policy messages_update_read on public.messages
  as permissive for UPDATE
  to public
  using (((sender_id IS DISTINCT FROM auth.uid()) AND (match_id IN ( SELECT matches.id
   FROM matches
  WHERE ((matches.user1_id = auth.uid()) OR (matches.user2_id = auth.uid()))))))
  with check (((sender_id IS DISTINCT FROM auth.uid()) AND (match_id IN ( SELECT matches.id
   FROM matches
  WHERE ((matches.user1_id = auth.uid()) OR (matches.user2_id = auth.uid()))))));

drop policy if exists users_manage_own_preferences on public.notification_preferences;
create policy users_manage_own_preferences on public.notification_preferences
  as permissive for ALL
  to public
  using ((auth.uid() = user_id));

drop policy if exists "Service role all notifications" on public.notifications;
create policy "Service role all notifications" on public.notifications
  as permissive for ALL
  to public
  using ((auth.role() = 'service_role'::text));

drop policy if exists "Users delete own notifications" on public.notifications;
create policy "Users delete own notifications" on public.notifications
  as permissive for DELETE
  to public
  using ((user_id = auth.uid()));

drop policy if exists "Users see own notifications" on public.notifications;
create policy "Users see own notifications" on public.notifications
  as permissive for SELECT
  to public
  using ((user_id = auth.uid()));

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications" on public.notifications
  as permissive for UPDATE
  to public
  using ((user_id = auth.uid()));

drop policy if exists payments_own_read on public.payments;
create policy payments_own_read on public.payments
  as permissive for SELECT
  to public
  using ((auth.uid() = user_id));

drop policy if exists places_read on public.places;
create policy places_read on public.places
  as permissive for SELECT
  to authenticated
  using (is_active);

drop policy if exists "Users create own reports" on public.reports;
create policy "Users create own reports" on public.reports
  as permissive for INSERT
  to public
  with check ((reporter_id = auth.uid()));

drop policy if exists "Users see own reports" on public.reports;
create policy "Users see own reports" on public.reports
  as permissive for SELECT
  to public
  using ((reporter_id = auth.uid()));

drop policy if exists service_manage_subscriptions on public.subscriptions;
create policy service_manage_subscriptions on public.subscriptions
  as permissive for ALL
  to public
  using ((auth.role() = 'service_role'::text));

drop policy if exists users_read_own_subscription on public.subscriptions;
create policy users_read_own_subscription on public.subscriptions
  as permissive for SELECT
  to public
  using ((auth.uid() = user_id));

drop policy if exists users_manage_own_devices on public.user_devices;
create policy users_manage_own_devices on public.user_devices
  as permissive for ALL
  to public
  using ((auth.uid() = user_id));

drop policy if exists photos_delete on public.user_photos;
create policy photos_delete on public.user_photos
  as permissive for DELETE
  to public
  using ((auth.uid() = user_id));

drop policy if exists photos_insert on public.user_photos;
create policy photos_insert on public.user_photos
  as permissive for INSERT
  to public
  with check ((user_id = auth.uid()));

drop policy if exists photos_select on public.user_photos;
create policy photos_select on public.user_photos
  as permissive for SELECT
  to public
  using (((moderation_status <> 'rejected'::text) OR (user_id = auth.uid())));

drop policy if exists photos_update on public.user_photos;
create policy photos_update on public.user_photos
  as permissive for UPDATE
  to public
  using ((auth.uid() = user_id));

drop policy if exists prompts_insert_own on public.user_prompts;
create policy prompts_insert_own on public.user_prompts
  as permissive for INSERT
  to authenticated
  with check ((user_id = auth.uid()));

drop policy if exists prompts_select_all on public.user_prompts;
create policy prompts_select_all on public.user_prompts
  as permissive for SELECT
  to authenticated
  using (true);

drop policy if exists prompts_update_own on public.user_prompts;
create policy prompts_update_own on public.user_prompts
  as permissive for UPDATE
  to authenticated
  using ((user_id = auth.uid()))
  with check ((user_id = auth.uid()));

drop policy if exists service_manage_stats on public.user_stats;
create policy service_manage_stats on public.user_stats
  as permissive for ALL
  to public
  using ((auth.role() = 'service_role'::text));

drop policy if exists users_read_own_stats on public.user_stats;
create policy users_read_own_stats on public.user_stats
  as permissive for SELECT
  to public
  using ((auth.uid() = user_id));

drop policy if exists users_insert on public.users;
create policy users_insert on public.users
  as permissive for INSERT
  to public
  with check ((auth.uid() = id));

drop policy if exists users_select on public.users;
create policy users_select on public.users
  as permissive for SELECT
  to authenticated
  using (true);

drop policy if exists users_update on public.users;
create policy users_update on public.users
  as permissive for UPDATE
  to public
  using ((auth.uid() = id));

drop policy if exists delete_own_profile_photos on storage.objects;
create policy delete_own_profile_photos on storage.objects
  as permissive for DELETE
  to authenticated
  using (((bucket_id = 'profile-photos'::text) AND ((auth.uid())::text = split_part(name, '/'::text, 1))));

drop policy if exists update_own_profile_photos on storage.objects;
create policy update_own_profile_photos on storage.objects
  as permissive for UPDATE
  to authenticated
  using (((bucket_id = 'profile-photos'::text) AND ((auth.uid())::text = split_part(name, '/'::text, 1))));

drop policy if exists update_own_selfie on storage.objects;
create policy update_own_selfie on storage.objects
  as permissive for UPDATE
  to authenticated
  using (((bucket_id = 'selfies'::text) AND ((auth.uid())::text = split_part(name, '/'::text, 1))));

drop policy if exists upload_own_profile_photos on storage.objects;
create policy upload_own_profile_photos on storage.objects
  as permissive for INSERT
  to authenticated
  with check (((bucket_id = 'profile-photos'::text) AND ((auth.uid())::text = split_part(name, '/'::text, 1))));

drop policy if exists upload_own_selfie on storage.objects;
create policy upload_own_selfie on storage.objects
  as permissive for INSERT
  to authenticated
  with check (((bucket_id = 'selfies'::text) AND ((auth.uid())::text = split_part(name, '/'::text, 1))));

drop policy if exists view_own_selfie on storage.objects;
create policy view_own_selfie on storage.objects
  as permissive for SELECT
  to authenticated
  using (((bucket_id = 'selfies'::text) AND ((auth.uid())::text = split_part(name, '/'::text, 1))));

drop policy if exists view_profile_photos on storage.objects;
create policy view_profile_photos on storage.objects
  as permissive for SELECT
  to authenticated
  using ((bucket_id = 'profile-photos'::text));

