-- 19.08.2026 — Engelleme tek kapı (Mustafa kararı, senaryo denetimi B3/B4):
-- Profilden engelleme yalnız blocks satırı yazıyordu → eşleşme açık kalıyor (sohbet listede,
-- mesaj denemesi hata), engelli çiftin bekleyen başvuruları listelerde ölü mekanik olarak
-- kalıyordu. Sohbetten engelleme ise matches.blocked_at'i de yazıyordu (18.08).
-- Çözüm: blocks INSERT'inde sunucu (a) çiftin açık eşleşmelerini bayraklar (blocked_by =
-- engelleyen, blocked_at = now; engelleyenin listesinden gizler), (b) çiftin 'pending'
-- başvurularını sessizce 'withdrawn' yapar (bildirim yok — §4 sessizlik). Geri alınamaz
-- (engel kaldırma ayrı karar). İstemci değişikliği gerekmez.

create or replace function public.on_block_inserted()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  -- (a) eşleşmeleri kapat (iki yön)
  update public.matches m
     set blocked_by = new.blocker_id,
         blocked_at = now(),
         user1_hidden_at = case when m.user1_id = new.blocker_id then coalesce(m.user1_hidden_at, now()) else m.user1_hidden_at end,
         user2_hidden_at = case when m.user2_id = new.blocker_id then coalesce(m.user2_hidden_at, now()) else m.user2_hidden_at end
   where m.blocked_at is null
     and ((m.user1_id = new.blocker_id and m.user2_id = new.blocked_id)
       or (m.user1_id = new.blocked_id and m.user2_id = new.blocker_id));

  -- (b) bekleyen başvuruları sessizce geri çek (iki yön)
  update public.applications a
     set status = 'withdrawn'
    from public.invitations i
   where i.id = a.invitation_id
     and a.status = 'pending'
     and ((a.applicant_id = new.blocked_id and i.owner_id = new.blocker_id)
       or (a.applicant_id = new.blocker_id and i.owner_id = new.blocked_id));
  return new;
end $$;

drop trigger if exists trg_on_block_inserted on public.blocks;
create trigger trg_on_block_inserted
  after insert on public.blocks
  for each row execute function public.on_block_inserted();

revoke all on function public.on_block_inserted() from public, anon, authenticated;
