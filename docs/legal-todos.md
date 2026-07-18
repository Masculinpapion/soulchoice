# Hukuki Görevler ve Kayıtlar (RU Uyumluluk)

## Marka Tescili — Роспатент/ФИПС — BAŞVURULDU, HARÇ BEKLİYOR (18.07.2026)

SoulChoice marka başvuruları АРМ «Регистратор» üzerinden yapıldı (Haziran 2026,
Наталья Бердова ile birlikte yürütülüyor):

- **SoulChoice-001** — заявка №2026781417
- **SoulChoice-002** — заявка №2026781420

**Durum:** ФИПС'ten kabineye (АРМ «Регистратор») yazışmalar düştü — 25.06.2026 (her iki
başvuru), 30.06.2026 (002), 07.07.2026 (001). İçerikleri kabinede; büyük olasılıkla
kayıt bildirimi + harç tahakkuku (начисление пошлин).

**⏰ Harç (пошлина) son tarihi: Ağustos 2026 sonu.**

**Öncelik kararı (18.07.2026, Mustafa onayı):** ФИПС harç ödemesi + kabinedeki
yazışmaların işlenmesi, **launch sonrası İLK idari iş**. WIPO/Madrid (global tescil)
bundan sonraya ertelendi.

## Roskomnadzor — Kişisel Veri Operatörü Bildirimi (152-ФЗ) — TAMAMLANDI (07.07.2026)

SoulChoice için Roskomnadzor'a "kişisel veri işleme niyeti" bildirimi başarıyla gönderildi.

**Kayıt bilgileri:**
- Номер: 100344985
- Ключ: 18987186
- Durum (07.07.2026 itibarıyla): "Уведомление направлено на рассмотрение" (inceleme aşamasında)
- Durumu tekrar sorgulamak için: pd.rkn.gov.ru → Реестр операторов → Электронные формы заявлений → Проверка состояния уведомления

**Bildirimde beyan edilen bilgiler (özet):**
- Operatör: Аладаг Мустафа (ИП, ИНН: 773434444897, ОГРНИП: 326774600434708)
- Adres: 117525, Москва, Сумской проезд, д. 31, корп. 1, кв./офис 148, ком. 1
- İşleme amacı: Подготовка, заключение и исполнение гражданско-правового договора
- Toplanan veri kategorileri: ФИО, дата рождения, пол, email, адрес места жительства, номер телефона, фото-видео изображение лица (+ биометрические данные лица)
- Veri sahibi kategorileri: Клиенты, Посетители сайта
- Veri merkezi: Timeweb (ООО «ТАЙМВЭБ.КЛАУД», ИНН 7810945525, ОГРН 1227800052215), fiziksel adres: 117545, Москва, ул. Подольских Курсантов, д. 15Б
- Trans-sınır veri aktarımı: yok
- Kriptografik araç kullanımı: yok (sadece standart SSL/TLS)

**İlgili kod değişikliği — TAMAMLANDI (07.07.2026, commit 7376d922f):**

Kayıt akışına 3 aktif onay checkbox'ı eklendi: 18 yaş onayı, kişisel veri işleme onayı
(Gizlilik Politikası linkli), profil görünürlük onayı. Hiçbiri işaretlenmeden kayıt
tamamlama butonu devre dışı kalıyor.

Not: checkbox'lar `phone_screen.dart`'a DEĞİL, `profile_setup_screen.dart`'a (9. adım,
"Согласия") eklendi — çünkü phone_screen hem giriş hem kayıt için ortak ekran; oraya
koymak geri dönen kullanıcıları her girişte yeniden onaya zorlardı. profile_setup_screen
sadece yeni kullanıcıların gördüğü kayıt tamamlama ekranı, doğru hukuki nokta burası.

DB: `users.consent_given_at` + `users.consent_version` alanları eklendi
(`supabase/migrations/20260708_consent_tracking.sql`), her onayda audit amacıyla
dolduruluyor. Cihazda uçtan uca test edildi (buton disabled/enabled davranışı dahil).
