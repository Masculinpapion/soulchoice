# Apple 4.3(b) Aşma Stratejisi — TEK KAYNAK

**Tarih:** 14.08.2026 · **Karar sahibi:** Mustafa
**DURUM (15.08 ~03:30 MSK): RESUBMIT EDİLDİ — "Waiting for Review".**

## SONUÇ — fiilen izlenen yol (15.08 gece, Mustafa komutlarıyla)

§4'teki "feed inversiyonu" ürün paketi **İPTAL** (Mustafa kararı: mevcut kart
tasarımı korunur, uygulamaya dokunulmaz). Yerine uygulanan paket:

1. **7 yeni vitrin karesi** (Mustafa + Gemini üretimi premium set; Fable
   1320×2868'e ölçekledi, S05 dil yaması «мой→мои») — ASC 6.9" slotta,
   eski 4 kare silindi, sıra 01→07.
2. **ASC Reply gönderildi** — 14.08 telefon görüşmesine (Vadim/Richard,
   Mustafa+Natalia) isimli atıf + 4 yapısal fark + demo talimatı +
   "meaningfully different or improved experience" talebi.
3. **Demo sahne canlı:** Демо hesabında (385ea0eb…) davet «Ужин в White
   Rabbit» (id 33db9e96…) + Майя/Влада/Злата'dan 3 pending başvuru —
   reviewer seçim akışını uçtan uca yaşayabilir. Review bitene kadar
   bu veriye DOKUNULMAZ.
4. Resubmit AYNI submission üzerinden, build 115 bilinçli (yeni build
   swap'i gece riski alınmadı).
5. Slogan güncellendi: **"SoulChoice Moment"** ("Choose Your Night" emekli).

**Ret gelirse merdiven:** ①Apple Developer Forums vakası (personel
müdahalesi belgeli) ②kartlara dokunmayan ilk-açılış mekanik hikâyesi
(binary farkı) ile yeni tur. İtiraz hakkı YOK (harcandı). Yeni bundle
ID/hesap YASAK. iOS web seçeneği YOK (Mustafa kararı).

*(Aşağıdaki §4 ürün-paketi bölümü tarihsel kayıt olarak durur — uygulanmadı.)*

---

## 1. Durum özeti

- Submission `d9843766-e946-40b5-a2b9-06bf92f22e45` (iOS 1.0, build 115) — **Rejected, 4.3(b) Design: Spam**, "Unresolved Issues" durumunda, iptal edilmedi.
- **14.08 telefon görüşmesi YAPILDI** (Rusça; Mustafa + Natalia). Temsilcinin mesajı: dating kategorisi doygun; reviewer'ı **"stop in your tracks"** durduracak, mevcut uygulamalardan açıkça ayrılan bir mekanik görülmeli; **gerekli geliştirmeler sonrası resubmit MÜMKÜN**.
- Görüşme sonrası yazılı ASC mesajı (Vadim, 14.08 17:50 MSK): 4.3(b) korundu; "yeni uygulama gönderin / web app düşünün" şablon önerileri. **"Yeni uygulama" önerisi harfiyen UYGULANMAZ** (bkz. §3 yasaklar).
- Board itirazı: kullanıldı, yanıtsız — submission başına tek hak, o kanal bitti.
- **Mustafa kararı (14.08): iOS web/PWA yolu YOK. Tek hedef App Store'a girmek.**

## 2. Araştırma bulguları (14.08, üç koldan; kaynaklar dipte)

**Kural zemini:**
- 08.06.2026 guideline güncellemesi 4.3(b)'yi sertleştirdi ve dating'i **ismen** sayıyor. Aşılacak yazılı test: **"meaningfully different or improved experience"**. Tüm argümanlar bu ifadeyle kurulur.
- Reddedilen submission **Edit ile BİR KEZ düzenlenip** (yeni build dahil) aynı dosyadan resubmit edilebilir; mesaj geçmişi (görüşme kaydı dahil) korunur. "Reply to App Review" resubmit'e kadar açık (4000 karakter + ek dosya).
- Kategori tek başına kurtarmaz: "Dating" ayrı kategori değil (Social Networking altında örnek). Mekanik dating okunurken etiket değiştirmek 2.3 metadata retini de ekletebilir.

**Vaka analizi (2020-2026):**
- Salt itiraz/ısrarla giren klasik dating uygulaması YOK. Özellik listesi (gizlilik, video profil, mesaj limiti), UI redesign, kategori/isim değişikliği: belgeli başarısız. En farklılaşmış başarısız vaka: Rove (swipe yok, güvenlik puanları) — hâlâ dışarıda.
- **Belgeli güncel kazanma reçetesi (Pixllove, 2025):** telefon görüşmesi → temsilcinin istediği değişiklik AYNEN yapıldı → her yazışmada temsilci adı+tarih yazılı referans → gerekince Apple Developer Forums'ta vaka (App Review personeli forumda müdahale ediyor; 2 belgeli örnek) → onay.
- 2024-25'te YENİ girenler var: **Mackinaw** (03.2025, tek şehir, minicik geliştirici, adında "Date", yeni mekanik), DayofUs (07.2025), Breeze, FROM, Yuzu. Ortak nokta: **çekirdek döngüyü değiştiren ve ilk ekran görüntüsünden görünen mekanik**.
- İki geçiş şeridi: **A)** "not a dating app" IRL-sosyal (Timeleft/222/Pie/Invitor — grup formatı, profil vitrini yok); **B)** açıkça dating ama yapısal yeni buluşma döngüsü (Breeze "No Chat Just Dates", FROM "24 saatte gerçek randevu", Mackinaw). 88date ara şerit: "Dating. Networking. Lifestyle." + mekan/kulüp kimliği, Social Networking.
- **Emsal riski:** Bizim mekaniğin (davet→başvuru→sahibin seçimi) eski emsalleri mağazada yaşıyor: SkyLove, Chat&Yamo. "Benzersiz" iddiası bu ikisine karşı da yazılmalı (farklarımız: TEK kişi seçimi + hap seremonisi, zorunlu selfie, tek aktif davet, gerçek tarih/sayaç, seçim öncesi chat yok).
- RU vitrini "знакомства"ya kapalı değil (VK Знакомства 2023'te yeni girdi) — sorun kelime değil, iskelet algısı.

## 3. YAPILMAYACAKLAR (araştırma kanıtlı)

1. **Yeni bundle ID / yeni geliştirici hesabıyla aynı konsept göndermek** — kendisi 4.3 tetikleyicisi; hesap kapatmaya kadar belgeli risk. Vadim mailindeki "yeni uygulama" bu yüzden izlenmez.
2. Görünür değişiklik olmadan aynı build'i tekrar göndermek (güvenilirlik yakar, hesabı işaretletir).
3. "Dating değiliz" diye kategori/metadata oyunu (Apple işleve bakıp yeniden sınıflandırıyor; 2.3 reti eklenir).
4. Yeni yazılı itiraz/aynı argümanlı mesaj spam'i (03.08 kararı geçerli).

## 4. ONAYLI PLAN — "Şerit B + kelime disiplini"

Konum: *"Swipe yok, sohbet vitrini yok — şehrindeki gerçek bir etkinliğe TEK kişiyi seç."* Dating inkâr edilmez; büyük hikâyenin (gerçek buluşma daveti) parçası olarak konumlanır.

### Ürün paketi (kod, ayrı onayla)
1. **Feed inversiyonu** — `feed_screen.dart` kart hiyerarşisi: başrol etkinlik (kategori+başlık+tarih) + BÜYÜK canlı sayaç (mevcut `_TickingTimer` terfi eder); davet sahibi fotoğrafı kart içinde ikincil. Feed başlığı "şehrin bu haftaki buluşmaları" dili. (~2-3 gün + cihaz onay turu)
2. **İlk-açılış mekanik hikâyesi** — kayıt öncesi 3-4 ekranlık akış: davet → başvuru → TEK seçim (hap) → gerçek buluşma. Reviewer ve her yeni kullanıcı ilk 30 saniyede çekirdek döngüyü görür. (~1 gün)
3. **Seçim seremonisi görünürlüğü** — mevcut `DecisionScreen` (1 saat sayaç + kırmızı/mavi hap) demo hesapta hazır sahneyle sunulur: demo hesabın (+70000000001) BAŞVURULU aktif daveti hazır tutulur (test envanteri; canlı veri kurallarına uygun, iş bitince kanıtlı temizlik). Opsiyonel güçlendirme: başvuran tarafına canlı "seçim yapılıyor — kalan süre" durumu. (~1-2 gün + veri hazırlığı)
4. **Vitrin yenileme** — RU/EN ad-altbaşkı-açıklama yeniden yazımı ("meaningfully different" dilini taşıyan, dating-kelimesi-minimal); ekran görüntüsü seti 88date/Timeleft kalitesinde KONSEPT-öncelikli (insan vitrini değil mekanik anlatımı). iPhone kareleri: Natalia iPhone veya simülatör. (~1-2 gün + Mustafa tek tek onayı, C maddesi geleneği)

### Yazışma + gönderim sırası
5. **Resubmit'ten ÖNCE ASC cevabı:** 14.08 görüşmesinin (Vadim/Richard, tarih+isim) yazılı özeti + yapılan değişikliklerin "meaningfully different" diliyle listesi; SkyLove/Chat&Yamo'ya karşı fark cümleleri; demo hesap + kısa demo video eki (resmi olarak destekleniyor).
6. **Resubmit:** AYNI submission → Edit (tek düzenleme hakkı bilinçli kullanılır) → yeni build + güncel metadata → Resubmit. **Yalnız Mustafa komutuyla.**
7. **Ret gelirse merdiven:** Apple Developer Forums'ta vaka açmak (personel müdahalesi belgeli) → görünürlük/basın (Struck emsali). Board itirazı yok (harcandı).

### Android/RuStore etkisi
Flutter tek kod tabanı: 1-3 değişiklikleri Android'e de gider — bilinçli karar (Mustafa 14.08): etkinlik-sahnesi kimliği Android için de kazanç. Yayındaki sürümlere kendiliğinden hiçbir şey olmaz; Android mağaza gönderimi bekleyen ⑥ paketiyle birleştirilebilir, ayrı komutla.

### Beklenti
Belgeli kazanımlar aylar + birden çok deneme sürdü; tek denemede garanti yok. Bu paket, kanıtların işaret ettiği en yüksek olasılıklı el: temsilci istekleri aynen + yazılı referanslı + ilk-ekrandan görünür yapısal fark.

## 5. Kaynaklar (seçme)

- Guideline 4.3 (08.06.2026 metni): developer.apple.com/app-store/review/guidelines/ · değişiklik haberi: macrumors.com/2026/06/09/app-store-guidelines-low-quality-apps/
- Resubmit/Reply mekaniği: developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/ (reply + manage-unresolved-issues)
- Pixllove vakası: developer.apple.com/forums/thread/780651 · Rove: /thread/787880 · 57K MAU vakası: /thread/777838 · kategori relabel başarısızlığı: /thread/807879
- Yeni-bundle-ID riski: appcompliance.io/blog/apple-guideline-4-3-spam-rejection/ · molfar.io/blog/apple-review
- Emsaller: Timeleft id6466442949 · 222 id6450612690 · DayofUs id6748222136 · Mackinaw id6748755011 · Breeze id1478108023 · SkyLove id1226440933 · Chat&Yamo id1339782074 · Invitor id1261459156 · 88date id6447558348
