-- 03.09.2026 — OTP sertleştirme paketi (kalite teşhisi H3/H4 + PII + verify yarışı)
-- Sorunlar:
--  H3  send-call-otp throttle/insert ham telefonla çalışıyordu ("+7 999…" ≠ "+7999…" ≠ "+7(999)…").
--  H4  Günlük tavan (15/24s) call_otps BEFORE INSERT trigger'ındaydı; SMS insert'ten ÖNCE gidiyor,
--      insert hatası kontrol edilmiyordu → SMS gider, kod saklanmaz, istemci success:true görür.
--  PII Edge fonksiyonlar PostgREST'i ?phone=eq.… ile çağırıyordu → kong access log'una numara düşüyordu.
--  Yarış verify-call-otp attempts sayacını oku→karşılaştır→yaz yapıyordu (atomik değil).
-- Çözüm: tüm OTP durum mantığı SECURITY DEFINER RPC'lerde (yalnız service_role çağırır), telefon
-- gövdede taşınır, sayaç tek UPDATE ile artar, tavan gönderimden ÖNCE sorulur.
-- Bypass listesi prod'daki hâliyle (7 numara) — repo/prod drift'i burada kapanır.
begin;

alter table public.otp_send_log add column if not exists channel text;
alter table public.otp_send_log add column if not exists result  text;

create or replace function public.otp_norm(p_phone text)
returns text language sql immutable as $$
  select regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
$$;

create or replace function public.otp_is_bypass(p_norm text)
returns boolean language sql immutable as $$
  select p_norm in ('70000000001','70000000002','70000000003','70000000004',
                    '70000000005','70000000006','70000000007')
$$;

-- Tavan: 24 saatte 15 BAŞARILI gönderim (fail:* satırları sayılmaz — sms.ru kesintisi kullanıcının hakkını yemesin).
create or replace function public.enforce_otp_daily_cap()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_norm text := public.otp_norm(new.phone);
begin
  if public.otp_is_bypass(v_norm) then
    return new;
  end if;
  if (select count(*) from public.otp_send_log
       where phone = v_norm and created_at > now() - interval '24 hours'
         and coalesce(result, '') not like 'fail:%') >= 15 then
    raise exception 'OTP_DAILY_CAP';
  end if;
  insert into public.otp_send_log (phone) values (v_norm);
  return new;
end $$;

-- 1) Gönderim ÖNCESİ: 'ok' | 'too_soon:<sn>' | 'cap'
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
         and coalesce(result, '') not like 'fail:%') >= 15 then
    return 'cap';
  end if;
  return 'ok';
end $$;

-- 2) Gönderim SONRASI saklama: eski kodları siler, yenisini yazar (trigger tavanı ikinci kez korur).
create or replace function public.otp_store(p_phone text, p_code text, p_channel text)
returns text language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_norm  text := public.otp_norm(p_phone);
  v_phone text := '+' || v_norm;
begin
  delete from public.call_otps where public.otp_norm(phone) = v_norm;
  insert into public.call_otps (phone, code, expires_at)
    values (v_phone, p_code, now() + interval '5 minutes');
  if not public.otp_is_bypass(v_norm) then
    update public.otp_send_log set channel = p_channel, result = 'sent'
     where id = (select max(id) from public.otp_send_log where phone = v_norm);
  end if;
  return 'ok';
exception when others then
  if sqlerrm = 'OTP_DAILY_CAP' then return 'cap'; end if;
  raise;
end $$;

-- 3) Başarısız gönderim kaydı (tavana sayılmaz, OTP dönüşüm alarmı için).
create or replace function public.otp_log_fail(p_phone text, p_channel text, p_reason text)
returns void language sql security definer set search_path = public, pg_temp as $$
  insert into public.otp_send_log (phone, channel, result)
    values (public.otp_norm(p_phone), p_channel, 'fail:' || left(coalesce(p_reason, '?'), 60))
$$;

-- 4) Doğrulama, atomik: 'ok' | 'invalid' | 'too_many'
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
    return 'too_many';
  end if;
  if v_row.code <> p_code then
    update public.call_otps set attempts = attempts + 1 where id = v_row.id;
    return 'invalid';
  end if;
  delete from public.call_otps where public.otp_norm(phone) = v_norm;
  return 'ok';
end $$;

revoke all on function public.otp_norm(text)                from public, anon, authenticated;
revoke all on function public.otp_is_bypass(text)           from public, anon, authenticated;
revoke all on function public.otp_precheck(text)            from public, anon, authenticated;
revoke all on function public.otp_store(text,text,text)     from public, anon, authenticated;
revoke all on function public.otp_log_fail(text,text,text)  from public, anon, authenticated;
revoke all on function public.otp_verify(text,text)         from public, anon, authenticated;
grant execute on function public.otp_precheck(text)           to service_role;
grant execute on function public.otp_store(text,text,text)    to service_role;
grant execute on function public.otp_log_fail(text,text,text) to service_role;
grant execute on function public.otp_verify(text,text)        to service_role;

commit;
