-- 04.09.2026 — Kritik yol E2E testi için iki tahsis edilemeyen test numarası (+7000-blok, OTP 1234).
-- Edge send-call-otp TEST_PHONES ile birlikte güncellenir (aynı commit). Kayıtlar is_test_user=true olur,
-- gece koşusu sonunda ops/e2e-cleanup.sql ile temizlenir.
begin;
create or replace function public.otp_is_bypass(p_norm text)
returns boolean language sql immutable as $$
  select p_norm in ('70000000001','70000000002','70000000003','70000000004',
                    '70000000005','70000000006','70000000007',
                    '70000000008','70000000009')
$$;
create or replace function public.zz_flag_test_phone() returns trigger
language plpgsql security definer as $$
begin
  if regexp_replace(coalesce(new.phone,''),'[^0-9]','','g') in ('70000000001','70000000002','70000000003','70000000004','70000000005','70000000006','70000000007','70000000008','70000000009') then
    new.is_test_user := true;
  end if;
  return new;
end $$;
commit;
