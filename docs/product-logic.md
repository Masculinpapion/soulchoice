# SoulChoice — Ürün Mantığı (TEK KAYNAK)

_Sürüm: 1.0 — 15.07.2026. Sahip: Mustafa. Koddan çıkarılan fiili davranış + Mustafa'nın ürün kararları._

**Bu belge nasıl kullanılır:** Burası ürünün *niyetidir*. Kod bu belgeyle çelişiyorsa **kod hatalıdır** (belge güncellenmediyse). Davranış değiştiren her PR önce bu belgeyle karşılaştırılır; bilinçli sapma belgeye işlenmeden merge edilmez. "Kod doğru çalışıyor ama ürün mantığına aykırı" sınıfı hataları (ör. 17.06 matches-CASCADE vakası) yakalamak için var.

Durum işaretleri: ✅ kodda böyle · 🔧 karar verildi, uygulanacak (launch öncesi) · 🕐 karar verildi, post-launch/uygun boşluk.

---

## 1. Temel kavram

Bir kullanıcı bir buluşma ilanı açar; karşı cinsten kullanıcılar başvurur; ilan sahibi seçer; kabul anında ikili sohbet açılır. Ürünün özü budur — gerisi bu akışın etrafındaki kurallardır. Feed ve keşfet her zaman yalnızca **karşı cinsi** gösterir (kullanıcı seçimi yok; bilinçli, RF mevzuat uyumu).

## 2. İki mod

| | **Davet (invite)** | **İstek (request)** |
|---|---|---|
| İlan | "Şu planım var, benimle gelecek biri arıyorum" | "Beni davet edecek biri arıyorum" |
| Başvuran | plana katılmaya talip olur | davet etmeye talip olur |
| Seçen | **her zaman ilan sahibi** | **her zaman ilan sahibi** |

Mekanik olarak iki mod birebir aynıdır (aynı tablolar, aynı akış); fark anlam ve ekran metinleridir. Feed'de ayrı sekmeler. ✅

## 3. Kategoriler (12)

restoran · konser · seyahat · kültür · sinema · tiyatro · kahve · bar · hediye · spor · yürüyüş · karaoke

Kategori yalnızca sunumu etkiler (ikon, filtre). **Kategoriye özgü kural yoktur ve eklenmeyecekse bu tablo değişmez.** ✅

## 4. İlan yaşam döngüsü ve süreler

```
active (6/12/24/48 saat — sahibi seçer)
  └─ süre dolunca → selecting (+48 saat sabit seçim penceresi)
        └─ pencere dolunca → closed
              └─ match'i YOKSA saatlik temizlikte kalıcı silinir (başvurularıyla)
              └─ match'i VARSA silinmez (sohbet başlığı verisi yaşar)
```

- Geçişler saatlik cron'larla olur; dakikası dakikasına değildir, saate yuvarlanır. ✅
- İlan `active` kaldığı sürece başvuru alır VE sahibi kabul verebilir; `selecting`'de yeni başvuru kapanır, seçim sürer. ✅
- **Süresi dolan bekleyen başvurular `expired` yapılır; detayda "seçim yapılmadı" görünür; başvurana bildirim GÖNDERİLMEZ — bilinçli sessizlik** (reddedilme hissi yaratmamak için). 🔧 (cron'a pending→expired adımı + detay metni)
- `event_date` (buluşmanın gerçek tarihi) opsiyoneldir, en erken +2 saat; sohbette etkinlik rozeti olur. ✅

## 5. Limitler ve Premium

- Kişi başına aynı anda **1 aktif Davet + 1 aktif İstek** (DB zorlar). ✅
- İlan açmak herkese ücretsiz ve (aktif-1 kuralı dışında) sınırsız. ✅
- **Başvuru: ömür boyu 1 ücretsiz; ilk başvuruda hak yakılır; sonrası premium.** ✅
- **Premium = sınırsız başvuru. Başka hiçbir şey açmaz.** Tek paket 1000₽/ay, kayıtlı karttan iptale kadar otomatik yenileme (Точка). Ödeme gecikmesinde grace-period boyunca premium düşürülmez. ✅
- Eşleşmiş çiftin yeni başvurusu da paywall'a takılır — **bilinçli tasarım**, istisna eklenmez (12.07 kararı). ✅

## 6. Seçim: "Serbest Seçim" modeli

**Her kabul ayrı sohbet açar; üst sınır YOKTUR — bilinçli tasarım** (15.07 kararı). Sahibi başvuranları tek tek değerlendirir; kabul → match + sohbet, ilan aktifse akış devam eder. Kötüye kullanım gözlenirse sınır eklenir; o gün bu bölüm güncellenir. ✅
- Kabul idempotenttir (aynı kişiye ikinci kabul yeni sohbet açmaz). ✅
- Red → başvurana bildirim (bölüm 9). ✅
- Başvuran istediği an geri çekebilir (`withdrawn`). ✅
- `slots_total` kolonu legacy'dir, uygulanmaz (bölüm 11).

## 7. Sohbet yaşam döngüsü

> **İlke:** Eşleşme kalıcı ilişkidir, ilan geçici bir kayıttır; sohbet yalnızca kullanıcı aksiyonuyla (engelleme, hesap silme) yok olabilir — **hiçbir otomatik süreç sohbet silemez.**

- Sohbet **yalnızca kabul anında** açılır; başka yolu yoktur. ✅
- İlandan bağımsız yaşar: ilan silinse de sohbet ve mesajlar korunur. ✅ (17.06 CASCADE vakasının dersi — bağ SET NULL)
- Okundu bilgisi: karşı taraf mesajı görünce işaretlenir; rozet buna göre söner. ✅ (15.07'de düzeltildi)
- **Engelleme:** match tamamen silinir → sohbet **iki taraf için de** mesajlarıyla yok olur + engel kaydı kalır. ✅
- **Buluşma mekaniği (canlandırılacak 🕐):** kabul anında ilanın `event_date`'i match'in `meeting_date`'ine kopyalanır; buluşma saatinden sonra iki tarafa "buluşma gerçekleşti mi?" anketi çıkar; buluşmadan 24 saat sonra sohbet arşive iner (arşiv sekmesinde durur, silinmez). Launch-kritik değil.

## 8. Hesap silme — "Silinen kullanıcı" modeli (15.07 kararı, canlı)

- Silinen kullanıcının: aboneliği iptal edilir (mali iz anonim kalır — yasal gereklilik), fotoğrafları depodan silinir, hesabı ve kişisel verisi tamamen gider. ✅
- **Karşı tarafların sohbetleri ve eski mesajları KORUNUR**; silinen taraf "Удалённый пользователь" görünür; o sohbete yeni mesaj yazılamaz (arayüz + DB çift kilit). ✅
- Şikâyet kayıtları moderasyon amaçlı anonim kalır. ✅
- İki taraf da silinirse sohbet saatlik temizlikte yok olur. ✅

## 9. Bildirim matrisi (hedef durum)

| Olay | Kime | In-app | Push | Not |
|---|---|---|---|---|
| Yeni başvuru | ilan sahibi | ✅ | ✅ | |
| **Kabul: "Seçildin! Sohbet açıldı"** | başvuran | 🔧 | 🔧 | **launch öncesi, öncelikli** (bugün hiçbir kanal yok — kırık) |
| Reddedildin | başvuran | ✅ | ❌ push bilinçli yok | |
| Süre doldu / seçilmedin | başvuran | **❌ bilinçli sessizlik** | ❌ | 15.07 kararı |
| Yeni mesaj | karşı taraf | ✅ | ✅ | |
| Selfie onaylandı | kullanıcı | ✅ | ❌ | 🔧 metin düzeltilecek: "mavi tik" değil, nötr "profilin doğrulandı" |
| Selfie reddedildi | kullanıcı | ✅ | ❌ | |

- **Tüm in-app bildirim metinleri RU/EN/TR lokalize edilecek** — bugün DB'de sabit Türkçe. 🔧 launch öncesi.
- Push'lar kullanıcının bildirim tercihlerine ve sessiz saatlere saygılıdır. ✅

## 10. Kayıt ve doğrulama

- Giriş yalnızca telefon + çağrı-OTP'dir (arama gelir, son 4 hane girilir); OTP yalnız kullanıcı butona basınca tetiklenir. ✅
- Selfie zorunludur; onaysız selfie ile ilan açılamaz. Herkes doğrulanmış olduğu için ayrıca "tik" rozeti yoktur (özellik 19.06'da kaldırıldı). ✅
- Store inceleme/demo girişi: `docs/store-review-demo.md`.

## 11. Legacy notları (post-launch temizlik 🕐)

- `applications.status`: `selected` hiç kullanılmıyor (kabul doğrudan `accepted` yazar) — `expired` ise 4. bölüm kararıyla KULLANIMA GİRİYOR.
- `invitations.status`: `matched` ve `cancelled` hiçbir kod tarafından set edilmiyor; yalnız bazı gösterim yerlerinde bekleniyor.
- `invitations.slots_total`: hep 1 yazılır, hiçbir yerde uygulanmaz ("Serbest Seçim" kararıyla anlamsızlaştı).
- İlan düzenleme: kapsam metin/mekan/kategori; status ve süre DB trigger'ıyla korunur — davranışsal risk düşük, böyle kalacak.

## 12. Açık iş listesi (bu belgeden doğan)

| İş | Öncelik |
|---|---|
| Kabul bildirimi (in-app + push, l10n) | 🔧 launch öncesi, öncelikli |
| In-app bildirim metinleri RU/EN/TR | 🔧 launch öncesi |
| Selfie onay metni nötrleştirme | 🔧 launch öncesi (bildirim l10n işiyle birlikte) |
| pending→expired cron adımı + "seçim yapılmadı" gösterimi | 🔧 launch öncesi |
| Buluşma/arşiv mekaniğinin canlandırılması | 🕐 uygun boşlukta |
| Legacy statü/kolon temizliği | 🕐 post-launch |
