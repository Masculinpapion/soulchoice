-- 13.07.2026 — OTP brute-force koruması (BÜYÜK DENETİM, launch-blocker)
-- verify-call-otp artık telefon başına denemeyi sayıyor; 5 yanlıştan sonra
-- kod iptal + kayıt silinir (yeni kod zorunlu). 4 haneli kod × sınırsız deneme
-- = hesap devralma açığıydı → kapatıldı. Prod'a 13.07 uygulandı.
alter table public.call_otps add column if not exists attempts int not null default 0;
