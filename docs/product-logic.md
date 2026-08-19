# SoulChoice — Ürün Mantığı (TEK KAYNAK)

_Sürüm: 1.9 — 16.07.2026. Sahip: Mustafa. Koddan çıkarılan fiili davranış + Mustafa'nın ürün kararları._

**Bu belge nasıl kullanılır:** Burası ürünün *niyetidir*. Kod bu belgeyle çelişiyorsa **kod hatalıdır** (belge güncellenmediyse). Davranış değiştiren her PR önce bu belgeyle karşılaştırılır; bilinçli sapma belgeye işlenmeden merge edilmez. "Kod doğru çalışıyor ama ürün mantığına aykırı" sınıfı hataları (ör. 17.06 matches-CASCADE vakası) yakalamak için var.

Durum işaretleri: ✅ kodda böyle · 🔧 karar verildi, uygulanacak (launch öncesi) · 🕐 karar verildi, post-launch/uygun boşluk.

_v1.10 değişiklikleri (18.08.2026): anti-fraud sertleştirme paketi — §14 (eşleşme kilidi, engelleme = kapatma+arşiv, hediye soğuması/metin filtresi, yem-değiştir kilidi, temas filtresi, selfie kapısı DB'de, no-show 24s, şikayet bağlamı). Sunucu CANLI 18.08; istemci tarafı sonraki mağaza paketinde._

_v1.9 değişiklikleri: selfie onay/red artık push da gönderiyor (§9 ✅ 16.07, Mustafa kararı); red gerekçesi selfie ekranında da gösteriliyor (§9 ✅ 16.07)._

_v1.1 değişiklikleri: başvuru/kabul kuralları artık sunucuda zorlanıyor (§5, §6, §10 ✅); kabul bildirimi eklendi (§9 ✅); yaş filtresi, sohbet silme, çift yönlü engelleme kararları işlendi (§5, §7 🔧)._

---

## 1. Temel kavram

Bir kullanıcı bir buluşma ilanı açar; karşı cinsten kullanıcılar başvurur; ilan sahibi seçer; kabul anında ikili sohbet açılır. Ürünün özü budur. Feed ve keşfet her zaman yalnızca **karşı cinsi** gösterir (kullanıcı seçimi yok; bilinçli, RF mevzuat uyumu). ✅

## 2. İki mod

| | **Davet (invite)** | **İstek (request)** |
|---|---|---|
| İlan | "Şu planım var, benimle gelecek biri arıyorum" | "Beni davet edecek biri arıyorum" |
| Başvuran | plana katılmaya talip olur | davet etmeye talip olur |
| Seçen | **her zaman ilan sahibi** | **her zaman ilan sahibi** |

Mekanik olarak iki mod birebir aynıdır; fark anlam ve ekran metinleridir. Feed'de ayrı sekmeler. ✅

## 3. Kategoriler (12)

restoran · konser · seyahat · kültür · sinema · tiyatro · kahve · bar · hediye · spor · yürüyüş · karaoke

Kategori yalnızca sunumu etkiler (ikon, filtre); ilan oluşturma akışında kategoriye göre soru metinleri/placeholder özelleşir (mekan, açıklama). **Davranışsal (süre/limit/seçim) kural farkı yoktur.** ✅

### 3.1 Kategori-akış iyileştirmeleri (15.07 denetimi — Mustafa kararları, launch-blocker DEĞİL, uygun boşlukta)
- **Hediye (gift):** Tarih/Saat adımı **opsiyonel** (hediye teslimi için sabit "etkinlik saati" doğaya aykırı). Tarihsiz gift'te buluşma anketi eşleşmeden 24 saat sonra çıkar (§7). ✅ 15.07
- **Seyahat (travel):** Tarih adımı **"Başlangıç tarihi"** olarak etiketlenecek (tek `event_date` çok-günlü seyahati temsil edemiyor). 🔧
- **Kültür (culture):** Mekan placeholder'ı "Mekan adı" → **"müze / sergi / galeri"** yönlendirmeli olacak (food'un "Restoran adı" netliği gibi). 🔧
- **Eser/sanatçı alanı (sinema/tiyatro/konser):** İPTAL — eklenmeyecek (başlık/açıklama yeterli). ✅ karar
- **Yürüyüş (walk):** Dokunulmayacak — akış doğasına uygun. ✅
- **Hediye link akışı (gerçek vaka: Liliya / Золотое Яблоко):** bkz. §3.2. 🔧

### 3.2 Hediye (gift) ürün linki — güvenli görünürlük modeli (Mustafa kararı 15.07, tasarım onayı bekliyor)
- Mekan sorusu "**Hediyeni nerede buluşup teslim almak istersin?**" netliğine ayrılır (mağazaya ürün aldırma çağrısı gibi okunmaz).
- **Ürün linki veya adı alanı Açıklama adımındadır** (mekan değil) — "Ne hediye etmek istiyorsun?" = ürün, alan da ürün; mekan adımı yalnız buluşma noktası. (Cihaz denetiminde mekan başlığı altında ürün alanı kavramsal çakışma yaratıyordu — taşındı.) ✅ 15.07
- Opsiyonel **ürün linki veya adı**: link (http/https) girilirse **beyaz liste** (goldapple/wildberries/ozon/market.yandex/lamoda/letoile) zorlanır; **düz metin** (ürün adı/tarifi) girilirse beyaz liste atlanır — kullanıcı link aramak zorunda değil. İkisi de **moderasyona** düşer (`status` pending→approved). Sohbet kartı: link tıklanır, metin sadece yazı. ✅ 15.07
- **KRİTİK görünürlük — yapısal garanti (ayrı tablo):** link, feed'de select edilen `invitations` tablosunda **TUTULMAZ** — ayrı `invitation_gift_links` tablosunda (invitation_id, url, status). RLS'te doğrudan SELECT policy'si **yok** → hiç kimse tabloyu okuyamaz. Erişim yalnız iki SECURITY DEFINER RPC'den: `get_gift_link(match_id)` (seçilen kişi = match tarafı + approved) + `get_own_gift_link(invitation_id)` (ilan sahibi, edit için). Seçilmeyenlerin match'i olmadığından linki hiç göremez. _(Not: kolon olarak `invitations`'a koymak DENENDİ ve E2E'de yabancıya sızdığı görüldü — RLS aktif-ilan satırının tüm kolonlarını açıyor + table-level GRANT column REVOKE'u eziyor; bu yüzden ayrı tablo. "Feed'de gizleme değil, erişim yokluğu.")_
- **Simetri:** gift kategorisi tam simetriktir — cinsiyet kısıtı yok (kadın da erkek de gift ilanı açıp link koyabilir, karşı taraf başvurup alabilir). ✅ kod doğrulandı 15.07.
- **Yasal disclaimer ✅ 15.07:** 🎁 kart altında "Bu alışveriş SoulChoice dışında, üçüncü taraf mağazada gerçekleşir; sorumluluk kullanıcılara aittir" (TR/RU/EN). App satışa aracılık etmez.
- **`gift × invite/request` semantiği ÇÖZÜLDÜ ✅ 15.07:** mekan sorusu + alt-başlık + açıklama ipucu artık `flowType`'a göre tutarlı ayrışıyor. **invite+gift** = owner **veren**: "Hediyeni nerede teslim etmek istersin?" / "teslim edeceğin nokta". **request+gift** = owner **alan**: "Nerede teslim almak istersin?" / "teslim alacağın nokta". (Cihaz denetiminde question ↔ subtitle çelişkisi yakalanıp giderildi — question ayrışmıyordu.)
- **"Aldım/almadım" işareti EKLENMEDİ (bilinçli, Mustafa 15.07):** sahte-işaret + app'e sorumluluk kayması riski; app satış/teslim tarafında görünmez kalır.
- **Uygulama fazları:** ①DB çekirdek ✅ · ②create UI ✅ · ③chat kartı + disclaimer ✅ · ④ops moderasyon: DB+agent ✅; panel UI + deploy + cihaz E2E 🔧 kaldı.

## 4. İlan yaşam döngüsü ve süreler

```
active (6/12/24/48 saat — sahibi seçer; ASLA plandan sonra bitmez, bkz. süre kuralı)
  └─ süre dolunca → selecting (+48 saat sabit seçim penceresi)
        └─ pencere dolunca → closed
              └─ match'i YOKSA saatlik temizlikte kalıcı silinir (başvurularıyla)
              └─ match'i VARSA silinmez (sohbet başlığı verisi yaşar)
```

- Geçişler saatlik cron'la olur; saate yuvarlanır. ✅
- `active` boyunca başvuru alır VE sahibi kabul verebilir; `selecting`'de yeni başvuru kapanır, seçim sürer. ✅
- **Kapanan (`closed`) ilanlarda seçilmeyen bekleyen başvurular saatlik temizlikte `expired` yapılır; detayda "seçim yapılmadı" görünür; başvurana bildirim GÖNDERİLMEZ — bilinçli sessizlik** (reddedilme hissi yaratmamak için). ✅ 15.07
- **NİHAİ KARAR (Mustafa 11.08 gece): Profil "Başvurularım" = ANLIK DURUM PANOSU; kart ömrü = ilan ömrü.** İlan canlıyken (`active`/`selecting`): "Beklemede" (sarı), "Kabul edildi" (yeşil), **reddedilen gri "ЗАВЕРШЕНО/TAMAMLANDI"** — açık "reddedildin" yazmaz ama kullanıcı boş yere umutlanmayıp sıradakine geçer; detay ekranı pasif butonu da aynı etiketi gösterir. **İlan kapanınca kart durumu ne olursa olsun düşer — kabul dahil** (ilişki Mesajlar'da). `withdrawn`/`expired` gizli. 30 gün saklama fikri aynı gece İPTAL — cleanup cron 15.07 orijinali (kapalı+match'siz hemen silinir). ✅ 11.08
- **Pano sırası (Mustafa 16.08): Kabul → Bekliyor → ЗАВЕРШЕНО; grup içinde yeniden→eskiye.** Yeniden başvuru (`withdrawn→pending`) = YENİ başvuru: DB trigger `trg_reset_created_at_on_reapply` `created_at`'i sıfırlar (`20260816_reapply_resets_created_at.sql`); sahip tarafındaki kuyrukta da (created_at ASC) yeniden başvuran sona gider. Kural kodu: `application_card_rules.dart` (`compareMyApplicationCards`, testli). ✅ 16.08
- **Test kartları da bu döngüye UYAR (Mustafa 19.08): canlılık motoru (`simulate_test_liveliness`) dolan test kartını yeniden doğururken üzerindeki TÜM başvuruları (gerçek kullanıcılarınki dahil; `selected/accepted` hariç) siler** — gerçek akışta matchsiz closed ilan başvurularıyla silindiği için aynı davranış. Önceki "gerçek başvuruya dokunma" istisnası kaldırıldı: gerçek kullanıcının başvurusu yeniden doğan kartta 21 gün "Bekliyor" kalıyordu (sahte sinyal). Migration `20260819_sim_purge_real_apps_on_rebirth.sql`, tek kaynak `ops/simulate_test_liveliness.sql`.
- **Senaryo denetimi 19.08 (4 alan, kanıtlı) — düzeltmeler:** (a) yenileme günü abone saatlik `downgrade_expired_premium` ile ~14–24 s free'ye düşüyordu (çekim günlük) → "çekim sırada" istisnası (`20260819_downgrade_renewal_window.sql`); (b) `notify_invitation_updated` push 401 (Authorization yok) → düzeltildi + edge 3 dilli şablon + uygulamada push rotası; (c) OTP girişi `setSession` `signedIn` yaymıyordu → girişte push token/hesap dili uygulanmıyordu → accessToken ile çağrı; (d) çıkışta `fcm_token` temizlenmiyordu (başka hesap aynı cihazda eski push'ları alırdı) → `clearPushTokenBeforeSignOut`; (e) telefon ekranı rakam/10 hane doğrulaması; (f) auth dinleyicilerine `onError` (çevrimdışı yenileme 'fatal' sayılmasın); (g) motor Демо guard'ı; (h) `/about` "3 ücretsiz". **Engelleme tek kapı (19.08, canlı): `blocks` INSERT trigger'ı çiftin eşleşmelerini bayraklar (sohbet iki tarafta kapanır, engelleyenden gizlenir) ve bekleyen başvurularını sessizce `withdrawn` yapar — profilden/sohbetten fark etmez (`20260819_block_closes_match_and_apps.sql`).** BACKLOG (karar): feed `limit 30` sunucuda/cinsiyet istemcide (gerçek kart ≥30 olunca vitrin görünmez); store/landing "24 saat" + questionnaire "18 yaş" metinleri; tek-seferlik ödeme webhook mutabakatı yok; tek-seferlik premium'da bitiş tarihi görünmüyor; cleanup fonksiyonu 15.07 'expired' adımını kaybetmiş (§4 satır 68 ile çelişir, etkisi yok). BİLGİ: görünür re-login (madde S) kodda mevcut.
- **Web Premium sayfası OTP (19.08, canlı):** `soulchoice.app/premium` artık uygulamayla aynı — SMS birincil (`channel:'sms'`), 60 sn sonra "Не пришло SMS? Получить код звонком" (çağrı, son 4 hane); RU/EN. Önceden yalnız çağrıydı (09.07 sayfası, 10.08 SMS geçişini almamıştı). Repo kopyası `docs/web/premium.html`.
- **Gerçek kartlar her zaman ÜSTTE (Mustafa 19.08, canlı):** `invitations.feed_rank` 0 = gerçek kullanıcı, 1 = vitrin (`is_test_user`), trigger sahibinden türetir, istemci yazamaz; feed ve Обзор `feed_rank asc, created_at desc` (istemci 19.08 paketi; eski istemci karışık sırada). Hukuki metin gerekmez (legal-counsel 19.08).
- **Test kartı İÇERİK ROTASYONU (Mustafa 19.08, canlı):** her test davet sahibinin 3 persona-uyumlu varyantı var (`test_invitation_variants`: seq0 = orijinal kart, seq1–2 yeni; gerçek mekân, şehir içi, RU); motor yeniden doğuşta sıradaki varyantı (kategori/başlık/açıklama/mekân/saat) uygular, `test_rotation_state` sırayı tutar; `event_date` = expires+1h sonrası ilk varyant saati (süre kuralı korunur). Amaç: "aynı kişi aynı kafede her gün az önce" sinyalini kaldırmak; yüz sayısı değişmez. Демо varyantsız → sabit. Geri alma: varyant tablosunu boşalt. Migration `20260819_test_invitation_rotation.sql`.
- `event_date` (buluşmanın gerçek tarihi) opsiyoneldir, en erken +2 saat; sohbette etkinlik rozeti olur. ✅
- **Süre kuralı (Mustafa 17.08): başvurular her zaman plandan ÖNCE kapanır — `expires_at ≤ event_date − 1 saat`.** Süre adımında plandan sonra biten seçenekler soluk ("Plandan sonra biter"); tıklanınca seçilmez, uyarı: "Bu süre planınla uyuşmuyor — planın N saat sonra. Daha kısa bir süre seç." En uzun seçenek bile aşıyorsa dinamik **"Plana kadar (N sa)"** kartı gelir ve yakın planda önseçilidir (aynı-gün planlar böylece ilk kez tutarlı). Tarih değişince seçim plana uydurulur. DB güvenlik ağı: `trg_clamp_expires_before_event` (`20260817_expires_before_event.sql`) sessiz kırpar. Hediye (tarihsiz) muaf. ✅ 17.08 (`64d931d`)
- **Zorunlu alanlar (Mustafa 17.08): boş/yarım kart yok** — her adımın "İleri"si o adımı doğrular: kategori, başlık, **açıklama (her kategoride ≥10 karakter; seyahatte destinasyon)**, mekan, tarih (hediyede opsiyonel), plana uyan süre. Düzenleme ekranı aynı kuralları uygular. ✅ 17.08

## 5. Limitler, filtreler ve Premium

- Kişi başına aynı anda **1 aktif Davet + 1 aktif İstek** (DB zorlar). ✅
- İlan açmak herkese ücretsiz ve (aktif-1 kuralı dışında) sınırsız. ✅
- **Başvuru: ömür boyu 3 ücretsiz (Mustafa 19.08.2026; önce 1); her başvuruda (vitrin/test kartı DAHİL) hak yakılır; sonrası premium.** DB `users.free_applications_used` sayaç, eski `free_application_used` bayrağı = "3 hak da bitti" (eski istemci uyumu); `can_user_apply` < 3; mevcut kullanıcılar kullanılmış 1 ile devam. Uygulama: başvuru sonrası snackbar "kalan ücretsiz: N", paywall/err metinleri 3 dilde; Oferta §2 + Terms §6 RU/EN/TR 19.08 redaksiyonu (esaslı değil); landing RU/EN + llms.txt; store_listing.md. Migration `20260819_free_apps_3_and_feed_rank.sql`. ✅
- **Premium = sınırsız başvuru. Başka hiçbir şey açmaz.** Tek paket 1000₽/ay, kayıtlı karttan iptale kadar otomatik yenileme (Точка), ödeme gecikmesinde grace-period korumalı. ✅
- Eşleşmiş çiftin yeni başvurusu da paywall'a takılır — bilinçli, istisna yok (12.07). ✅
- **Geri çekilen başvuru aynı davete YENİDEN yapılabilir** (24.07, Mustafa kararı): withdrawn→pending geçişi RLS+trigger ile açık; yeniden-başvuruda INSERT ile aynı kurallar (ilan açık, selfie onaylı, hak/premium, askı yok) uygulanır ve davet sahibine yeni-başvuru bildirimi gider. Ücretsiz hak yalnız İLK başvuruda (INSERT) yakılır; geri çekmek hakkı geri getirmez. ✅
- **Bu kuralların TAMAMI artık sunucuda (DB trigger + RLS) zorlanır** — modifiye istemci bedava/sınırsız başvuramaz, kendi ilanına başvuramaz, doğrudan `accepted` insert edemez. ✅ (15.07 sertleştirme)
- **Yaş aralığı filtresi:** Kullanıcının Ayarlar'daki min/max yaş tercihi feed ve keşfette uygulanır (yalnız bu aralıktaki karşı-cins ilan sahipleri görünür). Tercih kalıcıdır ve UI'da kalır. ✅ 15.07

## 6. Seçim: "Serbest Seçim" modeli

**Her kabul ayrı sohbet açar; üst sınır YOKTUR — bilinçli tasarım** (15.07). Sahibi başvuranları tek tek değerlendirir; kabul → match + sohbet, ilan aktifse akış devam eder. Kötüye kullanım gözlenirse sınır eklenir; o gün bu bölüm güncellenir.
- Kabul kalıcı yazılır ve seçilen başvurana bildirim gider (§9). ✅ (15.07'de düzeltildi — önceden RLS sessizce yutuyordu)
- Kabul idempotenttir (aynı kişiye ikinci kabul yeni sohbet açmaz). ✅
- Red → başvurana bildirim (§9). ✅
- Başvuran istediği an geri çekebilir (`withdrawn`). ✅
- Başvuran yalnız kendi başvurusunu `withdrawn`, sahibi yalnız `accepted`/`rejected` yapabilir (RLS). ✅
- **Kabul edilen başvuran ilan kartını feed'de artık GÖRMEZ (11.08, Mustafa bulgusu):** "Хочу прийти" onun için ölü mekanikti (§13) — ilişki Mesajlar'a taşınmıştır. İlan diğer adaylara görünmeye devam eder (yukarıdaki serbest seçim kuralı değişmez). `pending`/`selected`/`rejected` görünürlüğü AYNEN kalır: selected'da başvuranın kararı bekleniyor, rejected'ı gizlemek sessizlik ilkesini deler (red sinyali sızar). ✅ 11.08
- `slots_total` kolonu legacy'dir, uygulanmaz (§11).

## 7. Sohbet yaşam döngüsü

> **İlke:** Eşleşme kalıcı ilişkidir, ilan geçici bir kayıttır; sohbet yalnızca kullanıcı aksiyonuyla (engelleme, hesap silme) yok olabilir — **hiçbir otomatik süreç sohbet silemez.**

- Sohbet **yalnızca kabul anında** açılır; başka yolu yoktur. ✅
- İlandan bağımsız yaşar: ilan silinse de sohbet ve mesajlar korunur. ✅ (17.06 CASCADE vakasının dersi — bağ SET NULL)
- Okundu bilgisi: karşı taraf mesajı görünce işaretlenir; rozet buna göre söner. ✅ (15.07 fix)
- **Engelleme:** match tamamen silinir → sohbet **iki taraf için de** mesajlarıyla yok olur + engel kaydı kalır. Engelleme **çift yönlü süzülür**: engellediğim + beni engelleyen kişilerin ilanları feed/keşfette görünmez (`hidden_from_feed` RPC). ✅ 15.07
- **Sohbet menüsündeki "sil" → tek-taraflı "gizle" (WhatsApp standardı):** gizleyen kullanıcının listesinden sohbet kalkar; karşı tarafta aynen durur; mesaj geçmişi korunur (gizleme yalnız liste seviyesindedir). Gizlenen sohbete karşı taraftan **yeni mesaj gelince sohbet listeye geri döner**. Match **SİLİNMEZ** — yukarıdaki ilkeye uygun (otomatik/tek-taraflı süreç sohbeti yok etmez, yalnız listeden gizler). 🔧
- **Engelleme** bundan ayrıdır ve mevcut haliyle kalır: match tamamen silinir, sohbet iki taraftan da gider (bu, kullanıcının bilinçli "tam kesme" aksiyonudur). ✅
- **REVİZE 18.08 (anti-fraud, §14):** engelleme artık match'i SİLMEZ → `matches.blocked_by/blocked_at` bayrağı; sohbet iki taraf için kapanır (giriş kutusu yerine "Чат закрыт" bandı), engelleyenin listesinden düşer, karşı tarafta salt-okunur kalır; engelli çift mesaj/başvuru/seçim yapamaz (sunucu `MATCH_BLOCKED`). Eski istemcilerin "sil" akışı çalışmaya devam eder ama mesajlar silinmeden `messages_archive`'e kopyalanır (kanıt, 90 gün, yalnız ops). ✅ sunucu 18.08 · istemci sonraki paket
- **Buluşma mekaniği:** kabul anında ilanın `event_date`'i match'in `meeting_date`'ine kopyalanır (tarih varsa); buluşma saatinden sonra (tarihsiz gift'te eşleşme+24s sonra) iki tarafa "buluşma gerçekleşti mi?" anketi çıkar. ✅ 15.07
- **Sohbetler KALICIDIR (REVİZE KARAR 20.07.2026, Mustafa):** buluşma geçse de sohbet Mesajlar listesinde durur ve yazışma açık kalır — kullanıcı gizlemedikçe (tek-taraflı gizle) veya engellemedikçe hiçbir sohbet listeden düşmez. Eski "buluşmadan 24 saat sonra sohbet arşive iner" kuralı ve arşiv konsepti tamamen İPTAL (isArchived filtresi, arşiv banner'ı, salt-okunur kilit ve sohbet açılışındaki lazy `archived_at` yazımı kaldırıldı; hiçbir ekranın kullanmadığı ölü `archivedMatchesProvider` silindi). Davetiye kartının feed'den düşme mekaniği bundan bağımsızdır ve aynen kalır. ✅ 20.07
- **No-show (gerçek kurulum ✅ 15.07):** anket "hayır" → `confirm_meeting` SECURITY DEFINER RPC karşı tarafın `no_show_count`'unu artırır (**RLS `auth.uid()=id` yüzünden app-side fallback hiç çalışmıyordu — kırıktı, RPC ile düzeltildi**), eşik **2 → hesap askıya alınır**. **Gift no-show maddi kayıp içerdiğinden ağırlıklı: +2 (tek gift no-show'u suspend eder)** + `no_show_reported_by` işareti + `suspension_reason='gift no-show (maddi kayıp)'`. _(not: `matches.meeting_status` kolonu hâlâ güncelleniyor değil; §11 legacy)_
- **Askı/ban artık FİİLEN zorlanır (✅ 15.07 akşam):** askıdaki/banlı kullanıcı yeni ilan/başvuru/mesaj üretemez (`enforce_not_suspended` trigger, `ACCOUNT_SUSPENDED`), profili/ilanı feed-keşfette görünmez (`hidden_from_feed`), app açılışta tam ekran "hesap askıda" durumu + destek yolu gösterir (iç not olan `suspension_reason` EKRANDA GÖSTERİLMEZ). Ops banı GoTrue oturumunu da keser (banned_until + refresh token silme). Ayrıca istemcinin kendi `premium_until`/`free_application_used`/`no_show_count`/`suspended_at` kolonlarını değiştirmesi kapatıldı (bedava-premium açığıydı).

## 8. Hesap silme — "Silinen kullanıcı" modeli (15.07 kararı, canlı)

- Silinen kullanıcının: aboneliği iptal edilir (mali iz anonim kalır — yasal), fotoğrafları depodan silinir, hesabı ve kişisel verisi tamamen gider. ✅
- **Karşı tarafların sohbetleri ve eski mesajları KORUNUR**; silinen taraf "Удалённый пользователь" görünür; o sohbete yeni mesaj yazılamaz (arayüz + DB çift kilit). ✅
- Şikâyet kayıtları moderasyon amaçlı anonim kalır. ✅
- İki taraf da silinirse sohbet saatlik temizlikte yok olur. ✅

## 9. Bildirim matrisi (hedef durum)

| Olay | Kime | In-app | Push | Not |
|---|---|---|---|---|
| Yeni başvuru | ilan sahibi | ✅ | ✅ | |
| **Kabul: "Seçildin! Sohbet açıldı"** | başvuran | ✅ | ✅ | 15.07'de eklendi (in-app trigger + app push, l10n) |
| Reddedildin | başvuran | ✅ | ❌ push bilinçli yok | |
| Süre doldu / seçilmedin | başvuran | ❌ **bilinçli sessizlik** | ❌ | 15.07 kararı |
| Yeni mesaj | karşı taraf | ✅ | ✅ | |
| Selfie onaylandı | kullanıcı | ✅ | ✅ | 16.07: push eklendi (DB trigger → pg_net → send-notification, alıcı dilinde); metin nötr "Profil onaylandı ✓" |
| Selfie reddedildi | kullanıcı | ✅ | ✅ | 16.07: push eklendi, preset sebep push gövdesinde; sebep selfie ekranında da banner olarak görünür |
| **Seçim penceresi kapanıyor** | ilan sahibi | ✅ | ✅ | ✅ 15.07: `selecting` + bekleyen başvuru + ≤12h kala, TEK sefer (`owner_reminded_at`); saatlik selection-reminder cron |

- **Push l10n ALICININ dilinde (✅ 15.07):** `users.locale` (app dil ayarından senkron) + send-notification sunucu şablonları (selected/new_application/new_message/selection_reminder); istemcinin gönderdiği metin yalnız fallback. Eski "gönderenin dili" kalıbı kapandı.
- **Yeni mesaj push'u İÇERİK TAŞIMAZ (✅ 15.07, Mustafa kararı):** kilit ekranı gizliliği — başlık gönderen adı, gövde sabit "Yeni mesaj/Новое сообщение"; sunucu şablonu eski istemcilerin gönderdiği içeriği de ezer.
- **In-app bildirim metinleri `type`'a göre render-time l10n üretilir (RU/EN/TR).** DB'deki title/body yalnız fallback/kayıttır. ✅ _(ADIM 1'de "sabit TR" sanılmıştı — ekran zaten lokalize)_
- Push'lar kullanıcının bildirim tercihlerine ve sessiz saatlere saygılıdır. ✅ İstisna (REVİZE 31.07, belgeye işlenişi 11.08): yalnız SERVİS bildirimleri (premium_* ve account_suspended — para/hesap durumu, ФЗ-38) tercih ve sessiz-saat kapısına takılmaz. Selfie onay/red DAHİL geri kalan her şey sessiz saatlere TABİDİR — selfie push'u gece 03:00'te gidebiliyordu, 31.07'de bilinçli olarak kapı arkasına alındı (kod: send-notification isService).

## 10. Kayıt ve doğrulama

- Giriş yalnızca telefon + SMS-OTP ("SoulChoice" imzalı SMS, 4 haneli kod); yedek kanal çağrı-OTP ("SMS gelmedi mi? Kodu aramayla al" — arama gelir, son 4 hane). Kanalsız (eski build) istekler backend'de çağrıya düşer. OTP yalnız kullanıcı butona basınca tetiklenir. (18.07: SMS.ru gönderici adı 4 büyük operatörde onaylanınca SMS birincil oldu; ad onayı bekleyen operatörlerde SMS stok adla teslim edilir.) ✅
- **Selfie zorunludur:** onaysız selfie ile ne ilan açılabilir ne başvuru yapılabilir (ikisi de DB'de zorlanır). Herkes doğrulanmış olduğu için ayrı "tik" rozeti yoktur (özellik 19.06'da kaldırıldı). ✅
- Store inceleme/demo girişi: `docs/store-review-demo.md`.

## 11. Legacy notları (post-launch temizlik 🕐)

- `applications.status`: `selected` hiç kullanılmıyor (kabul doğrudan `accepted` yazar) — `expired` ise §4 kararıyla kullanıma giriyor.
- `invitations.status`: `matched` ve `cancelled` hiçbir kod tarafından set edilmiyor.
- `matches.meeting_status` (scheduled/happened/no_show): anket sonucundan güncellenmiyor; yalnız `meeting_confirmed_user1/2` boolean'ları yazılıyor. `no_show_reported_by uuid[]` de doldurulmuyor (no-show sayacı `users.no_show_count` üzerinden işliyor). İkisi de gösterim/analitik için bağlanabilir.
- `invitations.slots_total`: hep 1 yazılır, uygulanmaz ("Serbest Seçim" ile anlamsız).
- `matches.archived_at` + `matches.chat_archived`: arşiv konsepti 20.07.2026'da iptal edildi — artık hiçbir kod yazmıyor/okumuyor; DB'de kalan eski değerler etkisizdir (kolonlar post-launch temizlikte düşürülebilir).
- İlan düzenleme: kapsam metin/mekan/kategori; status ve süre DB trigger'ıyla korunur — böyle kalacak.

## 12. Açık iş listesi (bu belgeden doğan)

| İş | Öncelik | Durum |
|---|---|---|
| Başvuru/kabul kurallarını sunucuda zorlama (guard trigger + RLS) | launch-kritik | ✅ 15.07 |
| Kabul bildirimi (in-app + push, l10n) | launch-kritik | ✅ 15.07 |
| Selfie kapısını başvuruya da koyma | launch-kritik | ✅ 15.07 (guard trigger'a dahil) |
| Yaş aralığı filtresini feed/keşfete bağlama | launch öncesi | ✅ 15.07 |
| Engellemeyi çift yönlü süzme (beni engelleyeni ben de görmeyeyim) | launch öncesi | ✅ 15.07 |
| In-app bildirim metinleri RU/EN/TR | launch öncesi | ✅ (zaten render-time l10n'dı) |
| pending→expired cron adımı + "seçim yapılmadı" gösterimi | launch öncesi | ✅ 15.07 |
| Selfie onay metni nötrleştirme ("mavi tik" → nötr) | launch öncesi | ✅ 15.07 |
| Sohbet "sil" → tek-taraflı "gizle" (WhatsApp standardı, §7) | launch öncesi | ✅ 15.07 |
| Buluşma/arşiv mekaniğinin canlandırılması | — | ✅ 15.07 |
| Kategori-akış iyileştirmeleri (§3.1: gift tarih opsiyonel, travel başlangıç tarihi, culture placeholder) | 🕐 uygun boşluk | açık |
| Hediye ürün linki — güvenli görünürlük (§3.2: kolon+beyaz liste+moderasyon+get_gift_link RPC+sohbet kartı) | 🔧 tasarım onayı bekliyor | açık |
| Legacy statü/kolon temizliği | 🕐 post-launch | açık |

## 14. Anti-fraud kuralları (18.08.2026 denetimi — Mustafa kararı "hepsi çözülsün")

Sunucu: `supabase/migrations/20260818_antifraud_hardening.sql` (+ `_fix1`), canlı 18.08 15:00 MSK, 12 senaryo rollback-testiyle doğrulandı. Demo/test hesapları (`is_test_user`) içerik filtresi ve soğumadan **muaf** (Apple review sahnesi etkilenmez). Tüm hata token'ları istemcide `GuardError` → aurora snackbar ile yerelleştirilir.

| Kural | Nerede | Token |
|---|---|---|
| Eşleşmenin tarafları/daveti/kategorisi katılımcı tarafından değiştirilemez; `meeting_confirmed_*`/`no_show_reported_by` yalnız `confirm_meeting` (GUC `soulchoice.match_ok`) | trigger `prevent_matches_tamper` | (sessiz geri alma) |
| Engelleme = bayrak (`blocked_by/blocked_at`, tek sefer, geri alınamaz); engelli çift mesaj/başvuru/seçim yapamaz | trigger `enforce_message_allowed`, `enforce_application_rules`, `match_and_select` | `MATCH_BLOCKED` |
| Match silinirken mesajlar `messages_archive`'e (kanıt; ops `ops_report_messages(report_id)`) | trigger `archive_messages_before_match_delete` | — |
| Hediye daveti: 7 günde en fazla 3 (silinenler dahil, `invitation_create_log`) | trigger `enforce_invitation_rules` | `GIFT_INVITATION_COOLDOWN` |
| Hediye serbest-metin dalı: para/kart/СБП/sertifika/temas isteği yasak (yalnız ürün adı) | trigger `enforce_gift_link` | `GIFT_TEXT_INVALID` |
| Eşleşmeye kategori kopyalanır (`matches.invitation_category`) → davet silinse de gift no-show ağırlığı 2 kalır | trigger `matches_snapshot_category` | — |
| Başvuru varken kategori/akış değişmez; başlık/mekân/tarih/açıklama değişirse bekleyen başvuranlara `invitation_updated` bildirimi (30 dk dedupe) | trigger `enforce_invitation_rules`, `notify_invitation_updated` | `INVITATION_LOCKED_HAS_APPLICATIONS` |
| Cinsiyet ilk kayıttan sonra kilitli (sessiz) | trigger `enforce_profile_text_rules` | — |
| Temas filtresi (link, t.me/wa.me/vk, telegram/whatsapp, `@handle`, telefon): ad/bio/iş/eğitim, davet başlık/açıklama/mekân, prompt cevapları. Sohbet mesajları **muaf** (eşleşme sonrası iletişim meşru) | trigger'lar + `contains_contact_info()` | `CONTACT_INFO_NOT_ALLOWED` |
| Uzunluk: ad ≤30, iş/eğitim ≤60, mekân ≤80, prompt ≤150, mesaj ≤2000 (istemci `maxLength` aynı) | CHECK | — |
| Davet açmada selfie kapısı DB'de (başvurudaki gibi) | trigger `enforce_invitation_rules` | `SELFIE_NOT_APPROVED` |
| No-show ihbarı: buluşma saati VE eşleşmeden ≥24 saat geçmeden kabul edilmez (tarihsiz/geri tarihli hediye eşleşmesinde anında askı silahı kapandı) | `confirm_meeting` | `meeting_not_yet` |
| Şikayet: `match_id`/`invitation_id` bağlamı, `reported_name_snapshot`; `v_open_reports` LEFT JOIN (taraf silinse de kuyrukta kalır) + kanıt sayaçları; "Мошенничество / просьба денег" sebebi ilk sırada; sohbet menüsünden şikayet | migration + istemci | — |
| Sohbette bir kez görünen güvenlik bandı: "buluşmadan önce para/hediye göndermeyin, SoulChoice asla transfer istemez" (kapatılabilir, cihazda hatırlanır) | istemci | — |

**Kapanış taraması ekleri (18.08 akşam, canlı):** `20260818_otp_daily_cap.sql` — telefon başına 24 saatte 15 OTP kodu (demo numarası muaf; `call_otps` INSERT trigger'ı, aşımda kod saklanmaz → kaba-kuvvet kapanır; SMS gönderim öncesi kontrol edge tarafında Apple sonrası). `20260818_rls_exposure_fix.sql` — 18 ops görünümü (`v_*`) anon/authenticated'dan alındı; `invitations_select`/`photos_select` yalnız authenticated; `simulate_test_liveliness`/`cleanup_client_errors`/`downgrade_expired_premium`/yardımcı fonksiyonlar anon'dan alındı; users guard'a `warning_count` + BEFORE INSERT guard (ilk kayıtta is_admin/premium/selfie yazılamaz). İstemci: paywall oferta metni tıklanabilir link, onay metni "21 год". Ödeme yolu ayrı denetimde SAFE (webhook banka-doğrulamalı, idempotent).

**Bilinçli olarak YAPILMAYAN / ertelenen (18.08):**
- Fotoğraf yayın-öncesi moderasyonu — tek moderatörle yeni kullanıcı fotoğrafı saatlerce görünmez kalır; lansman UX'i bozar. 🕐 hacim gelince.
- `no_show_count/suspended_at/suspension_reason/warning_count` sütunlarının herkese okunur olması — mağazadaki istemciler bu sütunları select ediyor; revoke eski sürümleri kırar. 🕐 sonraki paket + `my_profile_private()` RPC.
- Askıdaki hesabın silinip aynı numarayla temiz kayıt olması + OTP IP başına gün sınırı — edge function değişikliği/deploy gerektirir; **Apple incelemesi bitene kadar deploy YOK** (OTP kesinti riski). 🕐

## 13. Kalıcı ürün-mantığı denetimi — "Kullanıcı Kapısı" (15.07.2026, Mustafa talebi)

**Amaç:** "Kod doğru ama kullanıcı için kırık" sınıfı hataları Mustafa'nın değil, geliştirme
sürecinin kendisinin yakalaması. Bu bölüm tek kaynak; repo `CLAUDE.md` buraya işaret eder.

### 13.1 Kapı: davranış değiştiren HER commit'ten önce cevaplanır

1. **Belge çelişkisi:** Bu değişiklik bu belgenin hangi bölümünü etkiliyor? Çelişiyorsa ya
   kod hatalıdır ya belge güncellenir (Mustafa kararıyla) — ikisi birden sessiz kalamaz.
2. **Kullanıcı haberi:** Kullanıcı bu değişikliği hangi ekranda/anda yaşayacak? Kaçırırsa
   ne görüyor? (Deep link / rozet / karşılama / boş-durum metni gerekiyor mu?)
3. **Bekleyen kullanıcı:** Yeni bir "sonsuz/habersiz bekleme" durumu doğuyor mu? (Başvuran,
   seçilen, ödeme yapan — kimse cevapsız sırada unutulmaz.)
4. **Para mağduriyeti:** Kullanıcının ödediği hâlde değer alamadığı bir an oluşuyor mu?
   (habersiz çekim, ödedi-ama-kilitli, çifte order…)
5. **Ölü mekanik:** Yazılan her flag/kolon/durumun bir OKUYANI var mı? Okuyansız yazı =
   çalışmayan özellik. _(Ders: `suspended_at` yazılıyordu ama hiçbir RLS/ekran okumuyordu —
   askıya alma fiilen yoktu, 15.07 taramasında yakalandı.)_
6. **Hata dili:** Sunucu reddi kullanıcıya anlaşılır ve lokalize metinle mi düşüyor, ham
   exception mı? (`e.toString()` snackbar'ı = kırık deneyim.)
7. **l10n:** Yeni her metin RU/TR/EN üçünde de var mı? (Çift-dil senkron kuralı.)
8. **Cihaz kanıtı:** Davranış değişikliği gerçek cihazda görüldü mü? ("Kod doğru, geçtim" yasak.)
9. **Kanal matrisi (24.07 eklendi):** Bu değişikliğin dokunduğu yolculukta kanal matrisinde
   (ekran durumu / push / zil / e-posta / i18n — `docs/ux-journey-audit.md`) yeni boşluk doğdu mu,
   mevcut boşluk kapandı mı? Matris güncellendi mi?

### 13.2 Yolculuk taraması: yeni akış/ekran eklendiğinde

Akışa giren kullanıcı **nereden geliyor**, çıkınca **nereye gidiyor**, akışı **kaçıran** ne
görüyor? — üç cevap da netleşmeden iş "bitti" sayılmaz. Ayrıca büyük dönüm noktalarında
(launch öncesi, büyük özellik sonrası) uçtan uca tam yolculuk taraması tekrarlanır ve
bulgular 🔴 launch-blocker / 🟠 ciddi / 🟡 iyileştirme öncelikleriyle raporlanır.

### 13.3 İşleyiş

- Kapıyı geçemeyen bulgu **önce Mustafa'ya raporlanır** (öncelik etiketiyle); ürün kararı
  gerektirmeyen objektif kusurlar teknik inisiyatifle düzeltilip raporlanabilir.
- Bu belge her ürün kararında güncellenir; commit mesajında ilgili § anılır.
- Kapı, PR/commit hazırlanırken uygulanır — sonradan değil.
