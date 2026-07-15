-- No-show mekanizmasını gerçekten kur (docs/product-logic.md §7, ürün denetimi #2).
-- ÖNCESİ KIRIK: increment_no_show RPC hiç yoktu + app fallback'i karşı tarafın
-- users satırını update etmeye çalışıyordu ama users RLS `auth.uid()=id` — yani
-- kimse karşı tarafın no_show_count'unu artıramıyordu → hiçbir no-show kaydolmuyor,
-- 2x-suspend hiç tetiklenmiyordu.
-- ÇÖZÜM: SECURITY DEFINER confirm_meeting RPC — kendi teyidini set eder, "gelmedi"
-- ise karşı tarafın sayacını güvenle artırır. Gift no-show maddi kayıp içerdiğinden
-- ağırlıklı (+2, tek olayda suspend eşiğine ulaşır) + no_show_reported_by işareti.

create or replace function public.confirm_meeting(p_match_id uuid, p_attended boolean)
returns void
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_is_user1 boolean;
  v_other uuid;
  v_gift boolean;
  v_weight int;
  v_newcount int;
begin
  select (m.user1_id = v_uid),
         case when m.user1_id = v_uid then m.user2_id else m.user1_id end
    into v_is_user1, v_other
    from public.matches m
   where m.id = p_match_id and (m.user1_id = v_uid or m.user2_id = v_uid);
  if not found then
    raise exception 'match bulunamadı veya katılımcı değil';
  end if;

  if v_is_user1 then
    update public.matches set meeting_confirmed_user1 = p_attended where id = p_match_id;
  else
    update public.matches set meeting_confirmed_user2 = p_attended where id = p_match_id;
  end if;

  -- "gelmedi" → karşı tarafın no-show sayacı (gift ağırlıklı) + işaret + suspend
  if not p_attended and v_other is not null then
    select exists (
      select 1 from public.invitations i
      join public.matches m on m.invitation_id = i.id
      where m.id = p_match_id and i.category = 'gift'
    ) into v_gift;
    v_weight := case when v_gift then 2 else 1 end;

    update public.matches
       set no_show_reported_by =
             array_append(coalesce(no_show_reported_by, '{}'::uuid[]), v_uid)
     where id = p_match_id
       and not (v_uid = any(coalesce(no_show_reported_by, '{}'::uuid[])));

    update public.users
       set no_show_count = coalesce(no_show_count, 0) + v_weight
     where id = v_other
    returning no_show_count into v_newcount;

    if v_newcount >= 2 then
      update public.users
         set suspended_at = coalesce(suspended_at, now()),
             suspension_reason = coalesce(
               suspension_reason,
               case when v_gift then 'gift no-show (maddi kayıp)' else '2x no-show' end)
       where id = v_other;
    end if;
  end if;
end;
$$;

revoke all on function public.confirm_meeting(uuid, boolean) from public;
grant execute on function public.confirm_meeting(uuid, boolean) to authenticated;
