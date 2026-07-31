# 31.07.2026 — İlk sistematik denetim (6 kol)

Bu belge, RuStore'da canlı olan uygulamada yapılan ilk kapsamlı denetimin
kalıcı kaydıdır. Ayrıntılı bulgu listesi ve backlog: memory
`project_security_audit_2026_07_31`.

## Kapatılan güvenlik açıkları (hepsi canlıda kanıtlandı)

| # | Açık | Kanıt (öncesi → sonrası) |
|---|------|--------------------------|
| 1 | `ops_*` moderasyon RPC'leri PUBLIC (herkes ban/selfie onayı yapabilirdi) | anon anahtarla kullanıcı listesi geldi → `42501 permission denied` |
| 2 | `send-notification` anahtarsız (sahte/phishing push) | 200 → `401 unauthorized`; sunucu yolu pg_net taklidiyle doğrulandı |
| 3 | `matches` INSERT: zorla eşleşme → istediğine DM | policy: yalnız davet sahibi + o davete başvurmuş kişi |
| 4 | `match_and_select`: geri çekilmiş başvuru zorla kabul | başvuru-ilan bağı + durum kontrolü eklendi |
| 5 | `users`: giriş yapan herkes TÜM telefon/e-posta/push token'ı çekebiliyordu | `select=phone` → `42501`; profil/feed/RPC yolları 200 |
| 6 | `selection-reminder` kimliksiz (hatırlatma zamanı manipüle edilebilir) | anahtarsız `401`, cron yolu `200` |
| 7 | `can_user_apply` başkasının hak durumunu sorguluyordu | yalnız kendi |

**Önemli ders:** kolon gizliliğinde yalnız `revoke select (kolon)` yetmiyor —
tablo geneli `GRANT` üstün geliyor. Doğru sıra: `revoke select on tablo` →
`grant select (güvenli kolonlar)`. İstemcide `select('*')` kullanılamaz.

## Yaptırım hataları
- `confirm_meeting` idempotent değildi: aynı kişi "gelmedi"ye iki kez basınca
  karşı taraf otomatik askıya giriyordu. Sayaç artık ilk bildirime bağlı,
  ayrıca buluşma saati gelmeden ihbar edilemez.
- `ops_unban_user` no-show askısını kaldıramıyordu (askıda `banned=false`) →
  haksız askı kalıcı hesap kaybıydı. Artık askıyı da kaldırır, sayacı sıfırlar.

## Ödeme dayanıklılığı
- Banka sorulamadığında körlemesine çekim → aynı dönem ikinci tahsilat riski.
  Artık fail-closed (`reconcileOnly`).
- `charge_unknown` kilidi mutabakatı da engelliyordu → para gitmiş, premium
  kapalı, kullanıcı bir daha ödeyemiyordu. Artık kilitliyken de bankaya sorulur.
- Bağlama ödemesinde mutabakat yoktu → webhook kaybolursa para gider, premium
  açılmaz. Artık expire öncesi bankaya sorulur.

## Açık kalan (ürün kararı bekliyor)
1. **İade akışı** — kod tabanında `refunded` yazan hiçbir yer yok; iade edilse
   premium geri alınmıyor ve ertesi ay yine çekiliyor.
2. **iOS paywall çıkmazı** — ödeme gizliyken başvuru hakkı biten kullanıcıya ne
   gösterileceği (App Store 3.1.1 steering sınırı).
