-- 17.08.2026 — Davet başvuruları her zaman plandan ÖNCE kapanır (Mustafa kararı 16-17.08).
-- Mekanik: expires_at dolunca 'selecting' (48 saate kadar seçim) → sohbet → buluşma;
-- expires_at > event_date olursa geçmiş bir plana başvuru alınır, seçim plandan sonra açılır.
-- İstemci: create_invitation_screen süre adımı uymayan seçeneği kabul etmez ("Plana kadar" seçeneği).
-- DB: sessiz güvenlik ağı — hata fırlatmaz, kırpar. Yalnız INSERT ve bu iki kolonun UPDATE'inde
-- çalışır (cron'un status güncellemeleri etkilenmez). Hediye (event_date NULL) muaf.
create or replace function public.clamp_expires_before_event()
returns trigger language plpgsql as $$
begin
  if new.event_date is not null and new.expires_at is not null
     and new.expires_at > new.event_date then
    new.expires_at := new.event_date;
  end if;
  return new;
end $$;

drop trigger if exists trg_clamp_expires_before_event on public.invitations;
create trigger trg_clamp_expires_before_event
  before insert or update of expires_at, event_date on public.invitations
  for each row execute function public.clamp_expires_before_event();
