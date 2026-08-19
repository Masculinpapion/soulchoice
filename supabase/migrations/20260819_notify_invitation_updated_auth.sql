-- 19.08.2026 — notify_invitation_updated: send-notification çağrısında Authorization header
-- eksikti (31.07 sertleştirmesi edge'de service key zorunlu kıldı) → in-app bildirim oluşuyor,
-- push sessizce 401. Diğer 6 notify_* trigger'ı ile aynı kalıba getirildi.
-- (Senaryo denetimi 19.08; henüz tetiklenmemişti: notifications type=invitation_updated 0 satır.)
CREATE OR REPLACE FUNCTION public.notify_invitation_updated()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
          headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));  -- 19.08: send-notification 401 düzeltmesi
      exception when others then null;
      end;
    end loop;
  exception when others then
    raise warning 'notify_invitation_updated: %', sqlerrm;   -- düzenlemeyi asla engelleme
  end;
  return new;
end $function$;
