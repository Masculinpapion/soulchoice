-- 15.10.2026: «Совпадение! 🎉» → «Тебя выбрали ✓» (açık akış, tüm platformlar; Apple 13.10 randevusu:
-- her yerde aynı dil). Fonksiyon gövdesi 20260726_server_push.sql ile aynı, yalnız başlık değişti.
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
        'title', 'Тебя выбрали ✓',
        'body', 'Чат с ' || COALESCE(other_name, '') || ' открыт',
        'data', jsonb_build_object('type', 'match', 'match_id', NEW.id),
        'template', jsonb_build_object('name', COALESCE(other_name, ''))),
      headers := '{"Content-Type": "application/json"}'::jsonb);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RETURN NEW;
END;
$function$;
