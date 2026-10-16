-- 16.10.2026: 20261015_match_push_title_open.sql eski (26.07) gövdeden kopyalanmıştı ve 31.07 güvenlik
-- düzeltmesindeki Authorization başlığı düşmüştü → send-notification 401 veriyor, «Тебя выбрали ✓» push'u gitmiyordu
-- (CI schema-drift 16.10 yakaladı). Başlık yeni, yetki başlığı geri.
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
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RETURN NEW;
END;
$function$;
