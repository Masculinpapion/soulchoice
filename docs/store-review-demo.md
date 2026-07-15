# Store İnceleme / Demo Girişi (KALICI)

_Oluşturma: 15.07.2026 — "Silinen kullanıcı" modeli çalışması sırasında._

## Demo hesap

| Alan | Değer |
|---|---|
| Telefon | **+7 000 000-00-01** |
| Doğrulama kodu | **1234** (sabit — arama GELMEZ, beklemeden girilir) |
| Profil | Демо, 30, erkek, Moskova, selfie onaylı, `is_test_user=true` |

Store incelemecisine verilecek metin (EN):
> Demo login: phone **+7 000 000 00 01**, verification code **1234** (no call is placed for this demo number — enter the code directly).

## Nasıl çalışıyor

- `supabase/functions/send-call-otp/index.ts` içindeki `TEST_PHONES` haritası; **yalnızca `ALLOW_TEST_OTP=true` iken** aktif (env: `/root/supabase/docker/.env`, compose `functions` servisi).
- Flag prod'da **AÇIK** tutulur (store incelemesi her an gelebilir). Güvenli çünkü:
  - Haritaya **yalnız gerçekte tahsis edilemeyen +7000-blok numaraları** girer (Rusya numara planında operatörlere verilmez) — gerçek kullanıcı çakışması imkânsız.
  - **Gerçek (aranabilir) numara ASLA eklenmez.** +79295774238 bypass'ı bu gerekçeyle 15.07.2026'da kaldırıldı: flag açıkken numarayı bilen herkes o hesaba girebilirdi.
- Demo numara SMS.ru'ya hiç gitmez → maliyet yok; 60 sn rate-limit muafiyeti var.
- Kapatmak istersen: `.env`'de `ALLOW_TEST_OTP=false` + `docker compose --env-file /root/supabase/docker/.env up -d --no-deps functions` (proje kökü `/root`).

## Demo hesabın içeriği

- **"Silinmiş kullanıcı" örnek sohbeti bilerek bırakıldı** (match `44444444-…`, 3 mesaj, karşı taraf silinmiş): hem hesap-silme modelinin kalıcı regresyon fikstürü hem de incelemeciye mesajlaşma ekranını gösterir. Silme!
- Hesap `is_test_user=true` — canlılık simülasyonu kurallarına tabi; gerçek kullanıcı metriklerine karışmaz.

## İlgili

- Silinen kullanıcı modeli: `supabase/migrations/20260715_deleted_user_model.sql` + `supabase/functions/delete-account/index.ts`
- Doğrulandı (15.07.2026): OTP araması YALNIZCA kullanıcı "Devam" / "Tekrar gönder" butonlarına basınca tetiklenir; otomatik SIM doldurma veya otomatik gönderim yoktur (kod: `phone_screen.dart` `_sendOtp`, `otp_screen.dart` resend).
