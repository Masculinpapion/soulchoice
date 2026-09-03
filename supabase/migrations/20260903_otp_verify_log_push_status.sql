-- 03.09.2026 — Kalite teşhisi (izleme B2/B3): OTP dönüşüm oranı ve push teslim oranı ölçülebilir olsun.
--  • otp_send_log.result artık doğrulama sonuçlarını da taşır ('verified' | 'wrong' | 'too_many');
--    günlük tavan YALNIZ gerçek gönderimleri sayar (result 'sent' veya eski NULL satırlar).
--  • push_log.status: 'sent_fcm' | 'sent_rustore' | 'fcm_fail' | 'rustore_fail' | 'unregistered' | 'no_token'
--    (send-notification yazar; checks.sh UNREGISTERED oranına bakar).
begin;

alter table public.push_log add column if not exists status text;

create or replace function public.enforce_otp_daily_cap()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_norm text := public.otp_norm(new.phone);
begin
  if public.otp_is_bypass(v_norm) then
    return new;
  end if;
  if (select count(*) from public.otp_send_log
       where phone = v_norm and created_at > now() - interval '24 hours'
         and coalesce(result, 'sent') = 'sent') >= 15 then
    raise exception 'OTP_DAILY_CAP';
  end if;
  insert into public.otp_send_log (phone) values (v_norm);
  return new;
end $$;

create or replace function public.otp_precheck(p_phone text)
returns text language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_norm text := public.otp_norm(p_phone);
  v_last timestamptz;
  v_age  numeric;
begin
  if public.otp_is_bypass(v_norm) then
    return 'ok';
  end if;
  select max(created_at) into v_last from public.call_otps where public.otp_norm(phone) = v_norm;
  if v_last is not null then
    v_age := extract(epoch from (now() - v_last));
    if v_age < 60 then
      return 'too_soon:' || ceil(60 - v_age)::int;
    end if;
  end if;
  if (select count(*) from public.otp_send_log
       where phone = v_norm and created_at > now() - interval '24 hours'
         and coalesce(result, 'sent') = 'sent') >= 15 then
    return 'cap';
  end if;
  return 'ok';
end $$;

create or replace function public.otp_verify(p_phone text, p_code text)
returns text language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_norm text := public.otp_norm(p_phone);
  v_row  public.call_otps%rowtype;
begin
  select * into v_row from public.call_otps
   where public.otp_norm(phone) = v_norm and expires_at > now()
   order by created_at desc limit 1
   for update;
  if not found then
    return 'invalid';
  end if;
  if v_row.attempts >= 5 then
    delete from public.call_otps where public.otp_norm(phone) = v_norm;
    insert into public.otp_send_log (phone, channel, result) values (v_norm, 'verify', 'too_many');
    return 'too_many';
  end if;
  if v_row.code <> p_code then
    update public.call_otps set attempts = attempts + 1 where id = v_row.id;
    insert into public.otp_send_log (phone, channel, result) values (v_norm, 'verify', 'wrong');
    return 'invalid';
  end if;
  delete from public.call_otps where public.otp_norm(phone) = v_norm;
  if not public.otp_is_bypass(v_norm) then
    insert into public.otp_send_log (phone, channel, result) values (v_norm, 'verify', 'verified');
  end if;
  return 'ok';
end $$;

commit;
