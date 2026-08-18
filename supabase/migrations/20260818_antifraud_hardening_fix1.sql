-- 18.08.2026 — antifraud fix1: notifications.type CHECK yeni 'invitation_updated' tipini içermiyordu →
-- başvurusu olan davette başlık/mekân/tarih düzenlemesi hata veriyordu (doğrulama T7'de yakalandı).
-- Ayrıca bildirim/push üretimi hiçbir koşulda düzenlemeyi engellemesin (exception yutulur).
begin;

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type = any (array[
  'new_application','selected','not_selected','new_message','selfie_approved','selfie_rejected',
  'meeting_reminder','feedback_request','selection_reminder','premium_activated','invitation_updated']));

create or replace function public.notify_invitation_updated()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare r record;
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then return new; end if;
  if (new.title, new.venue_name, new.event_date, new.description)
     is not distinct from (old.title, old.venue_name, old.event_date, old.description) then
    return new;
  end if;
  begin
    for r in select applicant_id from public.applications
              where invitation_id = new.id and status in ('pending', 'selected')
    loop
      if exists (select 1 from public.notifications
                  where user_id = r.applicant_id and type = 'invitation_updated'
                    and payload->>'invitation_id' = new.id::text
                    and created_at > now() - interval '30 minutes') then
        continue;
      end if;
      insert into public.notifications (user_id, type, title, body, payload)
      values (r.applicant_id, 'invitation_updated', 'Приглашение изменилось', new.title,
              jsonb_build_object('invitation_id', new.id, 'actor_id', new.owner_id));
      begin
        perform net.http_post(
          url := 'http://supabase-edge-functions:9000/send-notification',
          body := jsonb_build_object(
            'user_id', r.applicant_id,
            'title', 'Приглашение изменилось ✏️',
            'body', new.title,
            'data', jsonb_build_object('type', 'invitation_updated', 'invitation_id', new.id)),
          headers := '{"Content-Type": "application/json"}'::jsonb);
      exception when others then null;
      end;
    end loop;
  exception when others then
    raise warning 'notify_invitation_updated: %', sqlerrm;   -- düzenlemeyi asla engelleme
  end;
  return new;
end $$;

commit;
