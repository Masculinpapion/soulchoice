-- Ops: banı kaldırma RPC'si (29.07) — ops_ban_user'ın aynası, audit'li.
CREATE OR REPLACE FUNCTION public.ops_unban_user(p_user uuid, p_actor text, p_note text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
begin
  if coalesce(trim(p_note), '') = '' then raise exception 'not zorunlu'; end if;
  update public.users
     set banned = false, suspended_at = null, suspension_reason = null
   where id = p_user and banned = true;
  if not found then raise exception 'kullanıcı banlı değil ya da yok: %', p_user; end if;
  update auth.users set banned_until = null where id = p_user;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'unban_user', 'user', p_user, p_note);
end $$;

REVOKE ALL ON FUNCTION public.ops_unban_user(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ops_unban_user(uuid, text, text) TO ops_moderator;
