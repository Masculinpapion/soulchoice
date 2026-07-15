-- 16.07: selfie red sebepleri PRESET slug oldu (panelden seçilir:
-- face_unclear/too_far/accessories/lighting/mismatch/multiple_people).
-- Slug bildirim payload'ına yazılır; app kullanıcının DİLİNDE hazır
-- çeviriyi gösterir. Serbest metin dönemi kapandı (Mustafa kararı,
-- Natalya selfie E2E testi sırasında).

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
  ELSIF NEW.selfie_status = 'rejected' THEN
    INSERT INTO notifications(user_id, type, title, body, payload)
    VALUES (
      NEW.id, 'selfie_rejected', 'Selfie reddedildi',
      COALESCE('Sebep: ' || NEW.selfie_rejected_reason, 'Lütfen selfieni yeniden yükle.'),
      CASE WHEN NEW.selfie_rejected_reason IS NOT NULL
           THEN jsonb_build_object('reason', NEW.selfie_rejected_reason)
           ELSE '{}'::jsonb END
    );
  END IF;
  RETURN NEW;
END;
$$;

commit;

notify pgrst, 'reload schema';
