-- 16.07: selfie onay/red kararı artık PUSH da gönderiyor (Mustafa kararı 16.07,
-- önceden yalnız in-app vardı — kullanıcı onaylandığını fark etmeyebiliyordu).
-- Push, DB trigger'ından iç ağ üzerinden send-notification'a pg_net ile gider;
-- böylece panel / manuel SQL / gelecekteki her karar yolu tek noktadan kapsanır.
-- Metin ALICININ dilinde send-notification şablonundan üretilir (buradaki
-- title/body yalnız RU fallback). Push hatası kararı ASLA bloklamaz.

begin;

create or replace function public.notify_selfie_status()
returns trigger
language plpgsql
security definer
as $$
BEGIN
  IF OLD.selfie_status = NEW.selfie_status THEN RETURN NEW; END IF;

  IF NEW.selfie_status = 'approved' THEN
    INSERT INTO notifications(user_id, type, title, body, payload)
    VALUES (NEW.id, 'selfie_approved', 'Doğrulandın! 🎉', 'Artık davetlere katılabilirsin.', '{}');
    BEGIN
      PERFORM net.http_post(
        url := 'http://supabase-edge-functions:9000/send-notification',
        body := jsonb_build_object(
          'user_id', NEW.id,
          'title', 'Профиль подтверждён ✓',
          'body', 'Теперь ты можешь участвовать в приглашениях',
          'data', jsonb_build_object('type', 'selfie_approved')),
        headers := '{"Content-Type": "application/json"}'::jsonb);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  ELSIF NEW.selfie_status = 'rejected' THEN
    INSERT INTO notifications(user_id, type, title, body, payload)
    VALUES (
      NEW.id, 'selfie_rejected', 'Selfie reddedildi',
      COALESCE('Sebep: ' || NEW.selfie_rejected_reason, 'Lütfen selfieni yeniden yükle.'),
      CASE WHEN NEW.selfie_rejected_reason IS NOT NULL
           THEN jsonb_build_object('reason', NEW.selfie_rejected_reason)
           ELSE '{}'::jsonb END
    );
    BEGIN
      PERFORM net.http_post(
        url := 'http://supabase-edge-functions:9000/send-notification',
        body := jsonb_build_object(
          'user_id', NEW.id,
          'title', 'Фото отклонено',
          'body', 'Пожалуйста, загрузи новое селфи',
          'data', jsonb_build_object('type', 'selfie_rejected'),
          'template', jsonb_build_object('reason', NEW.selfie_rejected_reason)),
        headers := '{"Content-Type": "application/json"}'::jsonb);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;
  RETURN NEW;
END;
$$;

commit;

notify pgrst, 'reload schema';
