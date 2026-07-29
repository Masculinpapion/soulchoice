-- Ops Telegram alarmları (29.07.2026, madde 10a/10b/10f)
-- Yeni selfie / başarılı ödeme / yeni şikayet → alert botu kanalına anlık mesaj.
-- Yol: trigger → pg_notify('ops_alerts') → ops-agent LISTEN → /root/monitoring/alert.sh.
-- Neden doğrudan pg_net→Telegram değil: konteyner ağından api.telegram.org'a
-- TCP handshake zaman aşımı (29.07 teşhisi; FCM aynı ağdan çalışıyor, Telegram çalışmıyor);
-- host çıkışı sorunsuz + alert.sh retry/kuyruk/SMS-fallback'i hazır.

CREATE SCHEMA IF NOT EXISTS ops;

CREATE OR REPLACE FUNCTION ops.tg_notify(msg text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ops, public AS $$
BEGIN
  PERFORM pg_notify('ops_alerts', msg);
EXCEPTION WHEN OTHERS THEN
  NULL; -- alarm gönderilemedi diye asıl yazma işlemi bozulmaz
END $$;

-- 10a: yeni selfie moderasyona düştü
CREATE OR REPLACE FUNCTION ops.trg_tg_new_selfie() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ops, public AS $$
DECLARE uname text;
BEGIN
  IF NEW.is_selfie AND COALESCE(NEW.moderation_status, '') = 'pending' THEN
    SELECT name INTO uname FROM public.users WHERE id = NEW.user_id;
    PERFORM ops.tg_notify('🤳 Selfie onay bekliyor: ' || COALESCE(uname, NEW.user_id::text)
      || E'\nops.soulchoice.app → Moderasyon');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_tg_new_selfie ON public.user_photos;
CREATE TRIGGER trg_tg_new_selfie AFTER INSERT ON public.user_photos
  FOR EACH ROW EXECUTE FUNCTION ops.trg_tg_new_selfie();

-- 10b: ödeme paid oldu (insert veya pending→paid update)
CREATE OR REPLACE FUNCTION ops.trg_tg_payment_paid() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ops, public AS $$
DECLARE uname text;
BEGIN
  IF NEW.status = 'paid' AND (TG_OP = 'INSERT' OR COALESCE(OLD.status,'') <> 'paid') THEN
    SELECT name INTO uname FROM public.users WHERE id = NEW.user_id;
    PERFORM ops.tg_notify('💰 Ödeme alındı: ' || COALESCE(NEW.amount::text,'?') || ' '
      || COALESCE(NEW.currency,'RUB') || ' — ' || COALESCE(uname, 'kullanıcı')
      || ' (' || COALESCE(NEW.purpose,'') || ')');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_tg_payment_paid ON public.payments;
CREATE TRIGGER trg_tg_payment_paid AFTER INSERT OR UPDATE OF status ON public.payments
  FOR EACH ROW EXECUTE FUNCTION ops.trg_tg_payment_paid();

-- 10f: yeni şikayet
CREATE OR REPLACE FUNCTION ops.trg_tg_new_report() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ops, public AS $$
BEGIN
  PERFORM ops.tg_notify('🚨 Yeni şikayet: ' || COALESCE(NEW.reason,'?')
    || E'\nops.soulchoice.app → Moderasyon');
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_tg_new_report ON public.reports;
CREATE TRIGGER trg_tg_new_report AFTER INSERT ON public.reports
  FOR EACH ROW EXECUTE FUNCTION ops.trg_tg_new_report();
