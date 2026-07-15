# SoulChoice — Ürün Mantığı (TEK KAYNAK)

_Sürüm: 1.4 — 15.07.2026. Sahip: Mustafa. Koddan çıkarılan fiili davranış + Mustafa'nın ürün kararları._

**Bu belge nasıl kullanılır:** Burası ürünün *niyetidir*. Kod bu belgeyle çelişiyorsa **kod hatalıdır** (belge güncellenmediyse). Davranış değiştiren her PR önce bu belgeyle karşılaştırılır; bilinçli sapma belgeye işlenmeden merge edilmez. "Kod doğru çalışıyor ama ürün mantığına aykırı" sınıfı hataları (ör. 17.06 matches-CASCADE vakası) yakalamak için var.

Durum işaretleri: ✅ kodda böyle · 🔧 karar verildi, uygulanacak (launch öncesi) · 🕐 karar verildi, post-launch/uygun boşluk.

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

Kategori yalnızca sunumu etkiler (ikon, filtre). **Kategoriye özgü kural yoktur.** ✅

## 4. İlan yaşam döngüsü ve süreler

```
active (6/12/24/48 saat — sahibi seçer)
  └─ süre dolunca → selecting (+48 saat sabit seçim penceresi)
        └─ pencere dolunca → closed
              └─ match'i YOKSA saatlik temizlikte kalıcı silinir (başvurularıyla)
              └─ match'i VARSA silinmez (sohbet başlığı verisi yaşar)
```

- Geçişler saatlik cron'la olur; saate yuvarlanır. ✅
- `active` boyunca başvuru alır VE sahibi kabul verebilir; `selecting`'de yeni başvuru kapanır, seçim sürer. ✅
- **Kapanan (`closed`) ilanlarda seçilmeyen bekleyen başvurular saatlik temizlikte `expired` yapılır; detayda "seçim yapılmadı" görünür; başvurana bildirim GÖNDERİLMEZ — bilinçli sessizlik** (reddedilme hissi yaratmamak için). ✅ 15.07
- `event_date` (buluşmanın gerçek tarihi) opsiyoneldir, en erken +2 saat; sohbette etkinlik rozeti olur. ✅

## 5. Limitler, filtreler ve Premium

- Kişi başına aynı anda **1 aktif Davet + 1 aktif İstek** (DB zorlar). ✅
- İlan açmak herkese ücretsiz ve (aktif-1 kuralı dışında) sınırsız. ✅
- **Başvuru: ömür boyu 1 ücretsiz; ilk başvuruda hak yakılır; sonrası premium.** ✅
- **Premium = sınırsız başvuru. Başka hiçbir şey açmaz.** Tek paket 1000₽/ay, kayıtlı karttan iptale kadar otomatik yenileme (Точка), ödeme gecikmesinde grace-period korumalı. ✅
- Eşleşmiş çiftin yeni başvurusu da paywall'a takılır — bilinçli, istisna yok (12.07). ✅
- **Bu kuralların TAMAMI artık sunucuda (DB trigger + RLS) zorlanır** — modifiye istemci bedava/sınırsız başvuramaz, kendi ilanına başvuramaz, doğrudan `accepted` insert edemez. ✅ (15.07 sertleştirme)
- **Yaş aralığı filtresi:** Kullanıcının Ayarlar'daki min/max yaş tercihi feed ve keşfette uygulanır (yalnız bu aralıktaki karşı-cins ilan sahipleri görünür). Tercih kalıcıdır ve UI'da kalır. ✅ 15.07

## 6. Seçim: "Serbest Seçim" modeli

**Her kabul ayrı sohbet açar; üst sınır YOKTUR — bilinçli tasarım** (15.07). Sahibi başvuranları tek tek değerlendirir; kabul → match + sohbet, ilan aktifse akış devam eder. Kötüye kullanım gözlenirse sınır eklenir; o gün bu bölüm güncellenir.
- Kabul kalıcı yazılır ve seçilen başvurana bildirim gider (§9). ✅ (15.07'de düzeltildi — önceden RLS sessizce yutuyordu)
- Kabul idempotenttir (aynı kişiye ikinci kabul yeni sohbet açmaz). ✅
- Red → başvurana bildirim (§9). ✅
- Başvuran istediği an geri çekebilir (`withdrawn`). ✅
- Başvuran yalnız kendi başvurusunu `withdrawn`, sahibi yalnız `accepted`/`rejected` yapabilir (RLS). ✅
- `slots_total` kolonu legacy'dir, uygulanmaz (§11).

## 7. Sohbet yaşam döngüsü

> **İlke:** Eşleşme kalıcı ilişkidir, ilan geçici bir kayıttır; sohbet yalnızca kullanıcı aksiyonuyla (engelleme, hesap silme) yok olabilir — **hiçbir otomatik süreç sohbet silemez.**

- Sohbet **yalnızca kabul anında** açılır; başka yolu yoktur. ✅
- İlandan bağımsız yaşar: ilan silinse de sohbet ve mesajlar korunur. ✅ (17.06 CASCADE vakasının dersi — bağ SET NULL)
- Okundu bilgisi: karşı taraf mesajı görünce işaretlenir; rozet buna göre söner. ✅ (15.07 fix)
- **Engelleme:** match tamamen silinir → sohbet **iki taraf için de** mesajlarıyla yok olur + engel kaydı kalır. Engelleme **çift yönlü süzülür**: engellediğim + beni engelleyen kişilerin ilanları feed/keşfette görünmez (`hidden_from_feed` RPC). ✅ 15.07
- **Sohbet menüsündeki "sil" → tek-taraflı "gizle" (WhatsApp standardı):** gizleyen kullanıcının listesinden sohbet kalkar; karşı tarafta aynen durur; mesaj geçmişi korunur (gizleme yalnız liste seviyesindedir). Gizlenen sohbete karşı taraftan **yeni mesaj gelince sohbet listeye geri döner**. Match **SİLİNMEZ** — yukarıdaki ilkeye uygun (otomatik/tek-taraflı süreç sohbeti yok etmez, yalnız listeden gizler). 🔧
- **Engelleme** bundan ayrıdır ve mevcut haliyle kalır: match tamamen silinir, sohbet iki taraftan da gider (bu, kullanıcının bilinçli "tam kesme" aksiyonudur). ✅
- **Buluşma mekaniği:** kabul anında ilanın `event_date`'i match'in `meeting_date`'ine kopyalanır (ilanda buluşma tarihi varsa); buluşma saatinden sonra iki tarafa "buluşma gerçekleşti mi?" anketi çıkar; "hayır" → karşı tarafın no-show sayacı artar (2x → hesap askıya alınır); buluşmadan 24 saat sonra sohbet **arşive** iner (silinmez, arşiv sekmesinde durur). ✅ 15.07 _(not: `matches.meeting_status` scheduled/happened/no_show kolonu anket sonucundan güncellenmiyor — yalnız `meeting_confirmed_user1/2` yazılıyor; §11 legacy)_

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
| Selfie onaylandı | kullanıcı | ✅ | ❌ | 🔧 metin nötrleştirilecek: "mavi tik" değil, "profilin doğrulandı" |
| Selfie reddedildi | kullanıcı | ✅ | ❌ | |

- Push l10n çağıran tarafın (gönderenin) dilinde üretilir — mevcut kalıp; tüm push'lar böyle.
- **In-app bildirim metinleri `type`'a göre render-time l10n üretilir (RU/EN/TR).** DB'deki title/body yalnız fallback/kayıttır. ✅ _(ADIM 1'de "sabit TR" sanılmıştı — ekran zaten lokalize)_
- Push'lar kullanıcının bildirim tercihlerine ve sessiz saatlere saygılıdır. ✅

## 10. Kayıt ve doğrulama

- Giriş yalnızca telefon + çağrı-OTP (arama gelir, son 4 hane); OTP yalnız kullanıcı butona basınca tetiklenir. ✅
- **Selfie zorunludur:** onaysız selfie ile ne ilan açılabilir ne başvuru yapılabilir (ikisi de DB'de zorlanır). Herkes doğrulanmış olduğu için ayrı "tik" rozeti yoktur (özellik 19.06'da kaldırıldı). ✅
- Store inceleme/demo girişi: `docs/store-review-demo.md`.

## 11. Legacy notları (post-launch temizlik 🕐)

- `applications.status`: `selected` hiç kullanılmıyor (kabul doğrudan `accepted` yazar) — `expired` ise §4 kararıyla kullanıma giriyor.
- `invitations.status`: `matched` ve `cancelled` hiçbir kod tarafından set edilmiyor.
- `matches.meeting_status` (scheduled/happened/no_show): anket sonucundan güncellenmiyor; yalnız `meeting_confirmed_user1/2` boolean'ları yazılıyor. `no_show_reported_by uuid[]` de doldurulmuyor (no-show sayacı `users.no_show_count` üzerinden işliyor). İkisi de gösterim/analitik için bağlanabilir.
- `invitations.slots_total`: hep 1 yazılır, uygulanmaz ("Serbest Seçim" ile anlamsız).
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
| Sohbet "sil" → tek-taraflı "gizle" (WhatsApp standardı, §7) | 🔧 launch öncesi | planlandı |
| Buluşma/arşiv mekaniğinin canlandırılması | — | ✅ 15.07 |
| Legacy statü/kolon temizliği | 🕐 post-launch | açık |
