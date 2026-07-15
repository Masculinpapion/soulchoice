-- Seçilme bildirimi payload'ına match_id eklenir → in-app bildirime dokunma
-- (notifications_provider zaten payload.match_id → /chat/{id} yapıyor) ve
-- push deep link doğrudan sohbeti açar.
-- Not: hem decision akışı hem match_and_select RPC'si match'i application
-- güncellenmeden ÖNCE oluşturur; trigger anında match mevcuttur.
-- (Önceki sürüm: 20260715_application_rules_hardening.sql — SECURITY DEFINER korunur.)

begin;

create or replace function public.notify_application_status()
returns trigger
language plpgsql
security definer
as $$
DECLARE
  inv RECORD;
  owner_name TEXT;
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
  SELECT name INTO owner_name FROM users WHERE id = inv.owner_id;
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
  RETURN NEW;
END;
$$;

commit;

notify pgrst, 'reload schema';
