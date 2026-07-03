-- ─────────────────────────────────────────────────────────────────────────────
-- Bildirim payload'larına actor_id ekleniyor — kimin bu bildirime sebep
-- olduğu (mesaj gönderen, başvuran, davet sahibi) artık yapılandırılmış
-- olarak duruyor. Flutter tarafı bunu tek toplu sorguyla users+user_photos'a
-- join edip Instagram tarzı avatar+isim gösterebiliyor (ekstra N+1 sorgu yok).
-- title/body ve mevcut payload key'leri HİÇ değişmiyor, sadece actor_id ekleniyor.
-- notify_selfie_status'a dokunulmuyor (sistem bildirimi, actor yok).
-- ─────────────────────────────────────────────────────────────────────────────

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
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.notify_new_application()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  inv RECORD;
  applicant_name TEXT;
BEGIN
  SELECT * INTO inv FROM invitations WHERE id = NEW.invitation_id;
  SELECT name INTO applicant_name FROM users WHERE id = NEW.applicant_id;
  INSERT INTO notifications (user_id, type, title, body, payload)
  VALUES (
    inv.owner_id,
    'new_application',
    'Yeni Basvuru',
    applicant_name || ' davetinize basvurdu.',
    jsonb_build_object('invitation_id', NEW.invitation_id, 'application_id', NEW.id, 'actor_id', NEW.applicant_id)
  );
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.notify_application_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  inv RECORD;
  owner_name TEXT;
  notif_type TEXT;
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status = 'selected' THEN
    notif_type := 'selected';
  ELSIF NEW.status = 'rejected' THEN
    notif_type := 'not_selected';
  ELSE
    RETURN NEW;
  END IF;
  SELECT * INTO inv FROM invitations WHERE id = NEW.invitation_id;
  SELECT name INTO owner_name FROM users WHERE id = inv.owner_id;
  INSERT INTO notifications (user_id, type, title, body, payload)
  VALUES (
    NEW.applicant_id,
    notif_type,
    CASE notif_type
      WHEN 'selected' THEN 'Secildiniz!'
      WHEN 'not_selected' THEN 'Basvuru Sonucu'
    END,
    owner_name || ' davetinden haber var.',
    jsonb_build_object('invitation_id', NEW.invitation_id, 'application_id', NEW.id, 'actor_id', inv.owner_id)
  );
  RETURN NEW;
END;
$function$;
