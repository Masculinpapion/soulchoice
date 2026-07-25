-- 20260726_server_push.sql — Madde X: sosyal push'lar sunucu-tetikli + çift-push koruması
--
-- Neden: push'lar istemciden (gönderenin app'inden) atılıyordu; app ölürse/istisna
-- yutulursa push sessizce kayboluyordu (24-25.07 vakası). Selfie push deseni
-- (trigger → pg_net → send-notification) 4 sosyal olaya genişletiliyor.
-- Push bloğu ana işlemi ASLA bozamaz: EXCEPTION WHEN OTHERS THEN NULL.
--
-- Eski istemciler (build ≤618 / RuStore 608) push'u istemciden de atmaya devam
-- eder → send-notification'daki push_log dedupe'u (8 sn pencere) çifti yutar.
-- Yeni build'lerde istemci push kodu söküldü (aynı commit).

-- 1) Dedupe + gözlemlenebilirlik: push_log
CREATE TABLE IF NOT EXISTS push_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL,
  type text NOT NULL,
  ref text NOT NULL DEFAULT '',
  sent_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_push_log_dedupe ON push_log(user_id, type, ref, sent_at DESC);
ALTER TABLE push_log ENABLE ROW LEVEL SECURITY;  -- policy bilerek yok: yalnız service_role/superuser erişir

-- 2) Yeni mesaj → alıcıya push (içerik push'a KONMAZ — kilit ekranı gizliliği, 15.07 kararı)
CREATE OR REPLACE FUNCTION public.notify_new_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  match_rec RECORD;
  sender_name TEXT;
  recipient_id UUID;
BEGIN
  SELECT user1_id, user2_id INTO match_rec FROM matches WHERE id = NEW.match_id;
  SELECT name INTO sender_name FROM users WHERE id = NEW.sender_id;
  recipient_id := CASE WHEN match_rec.user1_id = NEW.sender_id THEN match_rec.user2_id ELSE match_rec.user1_id END;

  INSERT INTO notifications(user_id, type, title, body, payload)
  VALUES (
    recipient_id,
    'new_message',
    sender_name || ' mesaj gönderdi 💬',
    CASE WHEN length(NEW.content) > 60 THEN left(NEW.content, 60) || '…' ELSE NEW.content END,
    jsonb_build_object('match_id', NEW.match_id, 'sender_id', NEW.sender_id, 'actor_id', NEW.sender_id)
  );

  BEGIN
    PERFORM net.http_post(
      url := 'http://supabase-edge-functions:9000/send-notification',
      body := jsonb_build_object(
        'user_id', recipient_id,
        'title', '💬 ' || COALESCE(sender_name, ''),
        'body', 'Новое сообщение',
        'data', jsonb_build_object('type', 'new_message', 'match_id', NEW.match_id),
        'template', jsonb_build_object('name', COALESCE(sender_name, ''))),
      headers := '{"Content-Type": "application/json"}'::jsonb);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN NEW;
END;
$function$;

-- 3) Yeni başvuru → davet sahibine push (yeniden-başvuru dahil; mevcut UPDATE filtresi korunur)
CREATE OR REPLACE FUNCTION public.notify_new_application()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  inv RECORD;
  applicant_name TEXT;
begin
  -- UPDATE'te yalnız yeniden-başvuru (withdrawn→pending) bildirim üretir
  if TG_OP = 'UPDATE' and not (old.status = 'withdrawn' and new.status = 'pending') then
    return new;
  end if;

  select * into inv from invitations where id = new.invitation_id;
  select name into applicant_name from users where id = new.applicant_id;
  insert into notifications (user_id, type, title, body, payload)
  values (
    inv.owner_id,
    'new_application',
    'Yeni Basvuru',
    applicant_name || ' davetinize basvurdu.',
    jsonb_build_object('invitation_id', new.invitation_id, 'application_id', new.id, 'actor_id', new.applicant_id)
  );

  begin
    perform net.http_post(
      url := 'http://supabase-edge-functions:9000/send-notification',
      body := jsonb_build_object(
        'user_id', inv.owner_id,
        'title', 'Новая заявка 🔔',
        'body', coalesce(applicant_name, '') || ' хочет присоединиться',
        'data', jsonb_build_object('type', 'new_application', 'invitation_id', new.invitation_id),
        'template', jsonb_build_object('name', coalesce(applicant_name, ''))),
      headers := '{"Content-Type": "application/json"}'::jsonb);
  exception when others then null;
  end;

  return new;
end;
$function$;

-- 4) Seçildin → başvurana push (owner adı + RU fiil çekimi için cinsiyet şablona)
CREATE OR REPLACE FUNCTION public.notify_application_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  inv RECORD;
  owner_name TEXT;
  owner_gender TEXT;
  notif_type TEXT;
  v_match_id UUID;
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status IN ('selected', 'accepted') THEN
    notif_type := 'selected';
  ELSIF NEW.status = 'rejected' THEN
    notif_type := 'not_selected';
  ELSE
    RETURN NEW;
  END IF;
  SELECT * INTO inv FROM invitations WHERE id = NEW.invitation_id;
  SELECT name, gender INTO owner_name, owner_gender FROM users WHERE id = inv.owner_id;
  IF notif_type = 'selected' THEN
    SELECT id INTO v_match_id FROM matches
     WHERE invitation_id = NEW.invitation_id
       AND user2_id = NEW.applicant_id
     ORDER BY created_at DESC LIMIT 1;
  END IF;
  INSERT INTO notifications (user_id, type, title, body, payload)
  VALUES (
    NEW.applicant_id,
    notif_type,
    CASE notif_type
      WHEN 'selected' THEN 'Seçildin! 🎉'
      WHEN 'not_selected' THEN 'Başvuru sonucu'
    END,
    CASE notif_type
      WHEN 'selected' THEN owner_name || ' seni seçti — sohbet açıldı.'
      WHEN 'not_selected' THEN owner_name || ' davetinden haber var.'
    END,
    jsonb_build_object(
      'invitation_id', NEW.invitation_id,
      'application_id', NEW.id,
      'actor_id', inv.owner_id
    ) || CASE WHEN v_match_id IS NOT NULL
              THEN jsonb_build_object('match_id', v_match_id)
              ELSE '{}'::jsonb END
  );

  -- push yalnız 'selected' için (not_selected bilinçli push'suz — in-app yeter)
  IF notif_type = 'selected' THEN
    BEGIN
      PERFORM net.http_post(
        url := 'http://supabase-edge-functions:9000/send-notification',
        body := jsonb_build_object(
          'user_id', NEW.applicant_id,
          'title', 'Тебя выбрали! 🎉',
          'body', COALESCE(owner_name, '') || ' выбрал(а) тебя — чат открыт',
          'data', jsonb_build_object('type', 'selected', 'invitation_id', NEW.invitation_id)
                  || CASE WHEN v_match_id IS NOT NULL
                          THEN jsonb_build_object('match_id', v_match_id)
                          ELSE '{}'::jsonb END,
          'template', jsonb_build_object('name', COALESCE(owner_name, ''), 'gender', COALESCE(owner_gender, ''))),
        headers := '{"Content-Type": "application/json"}'::jsonb);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  RETURN NEW;
END;
$function$;

-- 5) Eşleşme → davet sahibine 'match' push ("Eşleşmeler" düğmesi artık gerçek bir
--    olayı yönetiyor; başvuran zaten 'selected' aldığı için ona ikinci push YOK)
CREATE OR REPLACE FUNCTION public.notify_new_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  other_name TEXT;
BEGIN
  SELECT name INTO other_name FROM users WHERE id = NEW.user2_id;
  BEGIN
    PERFORM net.http_post(
      url := 'http://supabase-edge-functions:9000/send-notification',
      body := jsonb_build_object(
        'user_id', NEW.user1_id,
        'title', 'Совпадение! 🎉',
        'body', 'Чат с ' || COALESCE(other_name, '') || ' открыт',
        'data', jsonb_build_object('type', 'match', 'match_id', NEW.id),
        'template', jsonb_build_object('name', COALESCE(other_name, ''))),
      headers := '{"Content-Type": "application/json"}'::jsonb);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_new_match ON matches;
CREATE TRIGGER trg_notify_new_match
  AFTER INSERT ON matches
  FOR EACH ROW EXECUTE FUNCTION notify_new_match();
