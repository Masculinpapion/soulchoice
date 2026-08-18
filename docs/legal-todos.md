# Hukuki Görevler ve Kayıtlar (RU Uyumluluk)

## Marka Tescili — Роспатент/ФИПС — HARÇLAR ÖDENDİ ✅ (17.08.2026), inceleme sürüyor

**17.08.2026 — 4 harç ödendi (Точка, ИП Аладаг Мустафа, платёжные поручения №5–8, toplam 55 000 ₽):**

| Заявка | Пункт | Сумма | УИН | П/п |
|---|---|---|---|---|
| 2026781417 (SoulChoice-001) | 2.1 | 7 000 ₽ | 16801000000135912464 | №5 |
| 2026781417 (SoulChoice-001) | 2.4 | 20 500 ₽ | 16801000000135912510 | №6 |
| 2026781420 (SoulChoice-002) | 2.1 | 7 000 ₽ | 16801000000135694335 | №7 |
| 2026781420 (SoulChoice-002) | 2.4 | 20 500 ₽ | 16801000000135694343 | №8 |

Получатель: Межрегиональное операционное УФК (Роспатент), ИНН 7730176088, КПП 773001001, счёт 03100643000000019500, БИК 024501901, ЕКС 40102810045370000002, КБК 16811505020016000140, ОКТМО 45318000, статус плательщика 08. Dekontlar + tahakkuk PDF'leri: `~/Desktop/FIPS-пошлины/`.

**Kaynak belgeler:** ФИПС «Уведомление о результатах проверки пошлины» — 002: 30.06.2026 (TMA260537887), 001: 07.07.2026 (TMA260557316): harç alınmamış, bildirimden 2 ay içinde öde → **son tarihler 002 = 30.08.2026, 001 = 07.09.2026** (gecikme ≤1 ay: ×2). Ödeme süre içinde yapıldı.

**Kabin:** АРМ «Регистратор» → https://kpsrtz.fips.ru/User/Login (Госуслуги + КриптоПро ЭЦП plug-in; yalnız Chromium-Gost). `new.fips.ru/office` ayrı servis, ilgisiz.

**Kalan:**
- [ ] 18–19.08: Точка'da №6–8 «Оплачено» olunca kaşeli PDF'lerle kabinde «Создать → Документ об уплате пошлины» (başvuru başına 1 belge, ЭЦП ile gönder) — tavsiye, zorunlu değil (УИН otomatik eşleşir)
- [ ] ~24.08: kabinde harç kabulü / inceleme durumu kontrolü; yoksa helpdesk@rupto.ru
- [ ] Formal → esas inceleme sonucu (aylar); WIPO/Madrid ertelenmiş

### Tarihçe — BAŞVURULDU, HARÇ BEKLİYOR (18.07.2026)

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

## 18.08.2026 — Hukuki metinler güncellendi + çok dilli (CANLI)
- Privacy / Terms / Oferta yeni redaksiyon **18.08.2026** yayında: soulchoice.app/{privacy,terms,oferta}; çeviriler `/en/…` ve `/tr/…` (bilgilendirme; RU bağlayıcı), sayfa üstünde RU·EN·TR geçişi; oferta iade bölümü `#refund` çapası. Uygulama linkleri dile göre açar (`lib/core/utils/legal_links.dart`, sonraki paket).
- **TEK KAYNAK artık repo:** `docs/legal/{privacy,terms,oferta}.html` (+ `en/`, `tr/`) — sunucuya buradan scp edilir; sunucuda `*.bak-20260818-legal` yedekleri, nginx yedeği `/root/backups/nginx-default.bak-20260818-legal`.
- İçerik: GPS ifadesi kaldırıldı (şehir elle), veri kategorileri/alıcılar (СМС.РУ, Google FCM+Crashlytics — sınır ötesi notu, Яндекс AppMetrica+Object Storage, Банк Точка, Таймвэб), saklama süreleri (§3.1), otomatik kararlar+moderasyon (§4.1), anında silme metni, РКН №100344985; Terms 21 yaş, temas/para yasağı, hediye kuralları (§3.1), yaptırımlar/engelleme/limitler (§6.1), 7 gün bildirim; Oferta "yalnız sınırsız başvuru", grace 24s, iade prosedürü (10 gün, banka), ihlal→iade yok, cookie/üçüncü taraf cümlesi Privacy'ye yönlendirildi.
- **Kural (Mustafa 18.08):** her ürün/kod/DB değişikliğinde `.claude/agents/legal-counsel.md` 8 soruluk kapı; gerekiyorsa metin + EN/TR birlikte güncellenir. `oferta_version` (feature_flags/consent) 2026-07-09'da bırakıldı — yeni yükümlülük yok, yalnız netleştirme; privacy için uygulama içi "güncellendi" bildirimi ayrı karar (backlog).
