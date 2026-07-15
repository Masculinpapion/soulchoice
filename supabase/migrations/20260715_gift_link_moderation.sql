-- Hediye linki moderasyonu (docs/product-logic.md §3.2, Faz 4). Ops panel
-- moderatörü pending linkleri görür + approve/reject eder. Mevcut selfie/report
-- moderasyon kalıbıyla aynı: izole ops_moderator rolü (v_* SELECT + ops_* EXECUTE),
-- audit_log kaydı. Link 'approved' olana kadar get_gift_link onu göstermez.

begin;

create or replace view public.v_pending_gift_links as
select l.invitation_id, l.url, l.created_at, i.title, u.name as owner_name
from public.invitation_gift_links l
join public.invitations i on i.id = l.invitation_id
join public.users u on u.id = i.owner_id
where l.status = 'pending'
order by l.created_at;

create or replace function public.ops_approve_gift_link(p_invitation_id uuid, p_actor text)
returns void
language plpgsql
security definer
as $$
begin
  update public.invitation_gift_links
     set status = 'approved', updated_at = now()
   where invitation_id = p_invitation_id and status = 'pending';
  if not found then raise exception 'gift link pending durumda değil: %', p_invitation_id; end if;
  insert into public.audit_log(actor, action, target_type, target_id)
  values (p_actor, 'approve_gift_link', 'gift_link', p_invitation_id);
end;
$$;

create or replace function public.ops_reject_gift_link(p_invitation_id uuid, p_reason text, p_actor text)
returns void
language plpgsql
security definer
as $$
begin
  update public.invitation_gift_links
     set status = 'rejected', updated_at = now()
   where invitation_id = p_invitation_id and status = 'pending';
  if not found then raise exception 'gift link pending durumda değil: %', p_invitation_id; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'reject_gift_link', 'gift_link', p_invitation_id, p_reason);
end;
$$;

grant select on public.v_pending_gift_links to ops_moderator;
grant execute on function public.ops_approve_gift_link(uuid, text) to ops_moderator;
grant execute on function public.ops_reject_gift_link(uuid, text, text) to ops_moderator;

commit;
