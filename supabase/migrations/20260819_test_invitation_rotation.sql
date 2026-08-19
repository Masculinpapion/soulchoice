-- 19.08.2026 — Test canlılık motoru: İÇERİK ROTASYONU (Mustafa kararı).
-- Sorun: yeniden doğan test kartı aynı kişi+aynı mekân+aynı başlıkla her gün
-- "az önce açıldı" görünüyordu → uygulamayı birkaç gün kullanan gerçek kullanıcı
-- fark eder (sahte sinyal). Çözüm: kişi başına 3 persona-uyumlu davet varyantı
-- (seq 0 = mevcut kart, seq 1–2 = yeni; gerçek mekân, şehir-içi, RU); motor her
-- yeniden doğuşta sıradaki varyantı uygular. Yüz sayısı değişmez — yalnız
-- inandırıcılık. Демо hesabı (385ea0eb) varyantsız → içerik sabit, motor zaten
-- dokunmuyor (demo-autoextend expiry'yi uzak tutuyor).
-- Kapsam dışı: Mustafa/Наталья (is_test_user=false), demo sahnesi.
-- Geri alma: test_invitation_variants'ı boşalt → motor eski davranışa döner
-- (varyant yoksa içerik aynen kalır); tablolar drop edilebilir.
-- Tek kaynak: ops/simulate_test_liveliness.sql. Prod: supabase_admin ile koş.

begin;

create table if not exists public.test_invitation_variants (
  id          bigserial primary key,
  owner_id    uuid not null references public.users(id) on delete cascade,
  seq         int  not null check (seq >= 0),
  category    text not null check (category in ('food','concert','travel','culture','cinema','theater','coffee','bar','gift','sport','walk','karaoke')),
  title       text not null check (char_length(title) between 1 and 60),
  description text not null check (char_length(description) between 10 and 300),
  venue_name  text not null check (char_length(venue_name) between 1 and 80),
  ev_hour     int  not null check (ev_hour between 0 and 23),   -- MSK saat
  created_at  timestamptz not null default now(),
  unique (owner_id, seq)
);
create table if not exists public.test_rotation_state (
  owner_id   uuid primary key references public.users(id) on delete cascade,
  seq        int not null default 0,
  updated_at timestamptz not null default now()
);
-- Yalnız sunucu tarafı (cron/service) kullanır: anon/authenticated'a kapalı.
alter table public.test_invitation_variants enable row level security;
alter table public.test_rotation_state      enable row level security;
revoke all on public.test_invitation_variants from public, anon, authenticated;
revoke all on public.test_rotation_state      from public, anon, authenticated;

-- seq 0 = mevcut canlı kart (test sahipleri; Демо hariç). Saat = mevcut event_date'in MSK saati.
insert into public.test_invitation_variants (owner_id, seq, category, title, description, venue_name, ev_hour)
select i.owner_id, 0, i.category, i.title,
       case when char_length(coalesce(i.description,'')) >= 10 then i.description else i.title end,
       coalesce(nullif(i.venue_name,''), i.title),
       coalesce(extract(hour from i.event_date at time zone 'Europe/Moscow')::int, 19)
  from public.invitations i
  join public.users u on u.id = i.owner_id
 where u.is_test_user and u.is_deleted = false and u.banned = false
   and left(u.id::text,8) <> '385ea0eb'
   and i.id = (select id from public.invitations where owner_id = u.id order by expires_at desc limit 1)
on conflict (owner_id, seq) do nothing;

-- seq 1–2: yeni varyantlar (62 kişi × 2)
insert into public.test_invitation_variants (owner_id, seq, category, title, description, venue_name, ev_hour) values
  ((select id from public.users where left(id::text,8)='e30378d3' and is_test_user), 1, 'coffee', 'Кофе на Покровке', 'После смены на кухне хочу просто сесть с чашкой и поговорить не про крем. Расскажу, почему эклер — это инженерия.', 'Кооператив Чёрный, Покровка', 15),
  ((select id from public.users where left(id::text,8)='e30378d3' and is_test_user), 2, 'food', 'Ужин в «Техникуме»', 'Иду учиться у чужих десертов. Заодно поужинаем и обсудим каждое блюдо.', 'Техникум, Большая Дмитровка', 20),
  ((select id from public.users where left(id::text,8)='1104ad3d' and is_test_user), 1, 'bar', 'Пятница в «Стрелке»', 'Хороший звук, вид на реку и никакого техно до полуночи. Потом — как пойдёт.', 'Бар Стрелка', 22),
  ((select id from public.users where left(id::text,8)='1104ad3d' and is_test_user), 2, 'walk', 'Вечер на Крымской набережной', 'Наушники оставим дома: город звучит сам. Пройдёмся от Музеона до Парка Горького.', 'Крымская набережная', 21),
  ((select id from public.users where left(id::text,8)='d4360c9b' and is_test_user), 1, 'culture', 'Выставка в «Гараже»', 'Покажу экспозицию глазами архитектора: что держит, что красиво, что обман. Потом кофе на веранде.', 'Музей «Гараж», Парк Горького', 16),
  ((select id from public.users where left(id::text,8)='d4360c9b' and is_test_user), 2, 'walk', 'Модерн на Остоженке', 'Мой маршрут по доходным домам и особнякам. Расскажу, что прячется за фасадами.', 'Остоженка', 18),
  ((select id from public.users where left(id::text,8)='79ee27be' and is_test_user), 1, 'coffee', 'Кофе в «Даблби»', 'Утро, фильтр и разговор о том, что сейчас читаете. Принесу книгу — отдам, если понравитесь.', 'Даблби, Милютинский переулок', 14),
  ((select id from public.users where left(id::text,8)='79ee27be' and is_test_user), 2, 'cinema', 'Кино в «Художественном»', 'Красивый зал, умное кино. После — спорить о финале до закрытия ближайшего бара.', 'Кинотеатр Художественный', 20),
  ((select id from public.users where left(id::text,8)='128ba78d' and is_test_user), 1, 'culture', 'Фотография в МАММ', 'Фотография — моя вторая любовь после шрифтов. Пройдёмся по залам и обсудим, что цепляет.', 'Мультимедиа Арт Музей, Остоженка', 17),
  ((select id from public.users where left(id::text,8)='128ba78d' and is_test_user), 2, 'walk', 'Вывески Китай-города', 'Покажу вывески, которые рисовала, и те, что хочу переделать. Кофе с собой.', 'Хохловский переулок', 19),
  ((select id from public.users where left(id::text,8)='cf18fd66' and is_test_user), 1, 'coffee', 'Кофе без собеседования', 'Собеседований не будет, обещаю. Просто кофе и честный разговор о путешествиях.', 'Surf Coffee, Никольская', 15),
  ((select id from public.users where left(id::text,8)='cf18fd66' and is_test_user), 2, 'food', 'Ужин на 22 этаже', 'Морепродукты и вид на город с высоты. Я коллекционирую рестораны — этот в топе.', 'Ресторан Сахалин', 20),
  ((select id from public.users where left(id::text,8)='968d5b49' and is_test_user), 1, 'walk', 'Фотопрогулка по ВДНХ', 'Снимаю на плёнку, вас — только с разрешения. Павильоны на закате и честные разговоры.', 'ВДНХ', 18),
  ((select id from public.users where left(id::text,8)='968d5b49' and is_test_user), 2, 'coffee', 'Кофе и отпечатки', 'Покажу последние отпечатки, а вы расскажете, что видите. Правильных ответов нет.', 'Кофемания, Кузнецкий Мост', 14),
  ((select id from public.users where left(id::text,8)='094a2e44' and is_test_user), 1, 'food', 'Пельмени и разговор о кино', 'Простая еда и длинный разговор о фильмах. Обещаю не советовать витамины.', 'Лепим и варим, Столешников', 19),
  ((select id from public.users where left(id::text,8)='094a2e44' and is_test_user), 2, 'coffee', 'Чай на Покровке', 'Я за чай, но кофе тоже можно. Главное — разговор о книгах, а не о витаминах.', 'Чайная высота, Покровка', 15),
  ((select id from public.users where left(id::text,8)='419236f1' and is_test_user), 1, 'theater', 'Вечер в «Современнике»', 'Беру два билета на вечерний спектакль. После — разбор за чаем, люблю спорить о финалах.', 'Театр «Современник»', 19),
  ((select id from public.users where left(id::text,8)='419236f1' and is_test_user), 2, 'coffee', 'Кофе между парами', 'Есть два часа до семинара. Докажу, что театр — не скучно, и что вы ошибались.', 'Кофемания, Большая Никитская', 16),
  ((select id from public.users where left(id::text,8)='6d4b6f9f' and is_test_user), 1, 'food', 'Ужин в «Северянах»', 'Печь, сезонное меню и никаких пресс-релизов. Пиарить буду только десерт.', 'Ресторан Северяне', 20),
  ((select id from public.users where left(id::text,8)='6d4b6f9f' and is_test_user), 2, 'cinema', 'Кино в «Пионере»', 'Хорошее кино, потом — негрони в ближайшем баре. Знаю, в каком.', 'Кинотеатр Пионер', 21),
  ((select id from public.users where left(id::text,8)='d419748a' and is_test_user), 1, 'walk', 'Утро в Ботаническом саду', 'Покажу, что цветёт прямо сейчас. Профессиональная деформация, зато красивая.', 'Главный ботанический сад РАН', 11),
  ((select id from public.users where left(id::text,8)='d419748a' and is_test_user), 2, 'culture', 'Икебана в Музее Востока', 'Японская графика и икебана — моя тема. Потом чай рядом, на Никитском.', 'Музей Востока, Никитский бульвар', 16),
  ((select id from public.users where left(id::text,8)='d8ddc84c' and is_test_user), 1, 'walk', 'Коломенское на закате', 'Деревянные наличники есть и в Москве — покажу, где. Потом яблоки из сада.', 'Музей-заповедник Коломенское', 17),
  ((select id from public.users where left(id::text,8)='d8ddc84c' and is_test_user), 2, 'travel', 'День в Коломне', 'Пастила, кремль и калачи. Выезжаем утром, возвращаемся другими людьми.', 'Коломна', 11),
  ((select id from public.users where left(id::text,8)='145aa070' and is_test_user), 1, 'bar', 'Коктейли в Noor', 'Громкая музыка, хорошие коктейли, никаких дедлайнов. Танцую, если зайдёт трек.', 'Noor Electro, Тверская', 22),
  ((select id from public.users where left(id::text,8)='145aa070' and is_test_user), 2, 'concert', 'Живой звук в «16 тоннах»', 'Стоячие места, хороший лайнап. Подпеваю громко — предупреждаю честно.', 'Клуб 16 тонн', 21),
  ((select id from public.users where left(id::text,8)='eb4847b7' and is_test_user), 1, 'culture', 'Третьяковка без спешки', 'Два зала вместо двадцати. Смотреть медленно — это искусство, научу.', 'Третьяковская галерея', 15),
  ((select id from public.users where left(id::text,8)='eb4847b7' and is_test_user), 2, 'walk', 'Купеческое Замоскворечье', 'Особняки и церкви в переулках. Расскажу, что видел этот район за триста лет.', 'Пятницкая улица', 18),
  ((select id from public.users where left(id::text,8)='b38f8d9a' and is_test_user), 1, 'coffee', 'Кофе не на моей смене', 'В выходной хочу, чтобы кофе варили мне. Обсудим, чей раф честнее.', 'Кафе «Март», Петровка', 14),
  ((select id from public.users where left(id::text,8)='b38f8d9a' and is_test_user), 2, 'concert', 'Лайв в «Китайском лётчике»', 'Маленькая сцена, живой звук, близко к музыкантам. После — бульвары пешком.', 'Китайский лётчик Джао Да', 21),
  ((select id from public.users where left(id::text,8)='60c6c9cb' and is_test_user), 1, 'walk', 'Утро на набережной Лужников', 'Быстрый шаг, свежий воздух и разговор. Без секундомера, честно.', 'Набережная Лужников', 10),
  ((select id from public.users where left(id::text,8)='60c6c9cb' and is_test_user), 2, 'coffee', 'Кофе после тренировки', 'Заслужила капучино и разговор не про технику приседа. Хотя могу и про неё.', 'Музеон, Крымская набережная', 12),
  ((select id from public.users where left(id::text,8)='90f0ce5e' and is_test_user), 1, 'food', 'Ужин в «Квартире 44»', 'Домашняя атмосфера и длинный разговор без диагнозов. Обещаю не анализировать. Почти.', 'Квартира 44, Большая Никитская', 20),
  ((select id from public.users where left(id::text,8)='90f0ce5e' and is_test_user), 2, 'culture', 'Выставка в Еврейском музее', 'Одна из лучших выставочных площадок города. После — чай и разговор о том, что зацепило.', 'Еврейский музей и центр толерантности', 15),
  ((select id from public.users where left(id::text,8)='99a21bde' and is_test_user), 1, 'walk', 'Хитровка: от трущоб до моды', 'Расскажу, как самый опасный район стал самым модным. Урбанистика — это детектив.', 'Хитровская площадь', 18),
  ((select id from public.users where left(id::text,8)='99a21bde' and is_test_user), 2, 'culture', 'Музей Москвы за час', 'Макеты, карты и план города 1739 года. Обещаю не читать лекцию. Ладно, маленькую.', 'Музей Москвы, Зубовский бульвар', 16),
  ((select id from public.users where left(id::text,8)='f87a750b' and is_test_user), 1, 'walk', 'Ивановская горка без туристов', 'Мой любимый маршрут: монастырь, переулки, виды. Без открыточного глянца.', 'Ивановская горка', 18),
  ((select id from public.users where left(id::text,8)='f87a750b' and is_test_user), 2, 'culture', 'Город на чертежах', 'Показываю Москву каждый день, а тут — она на бумаге. Редкий шанс помолчать и посмотреть.', 'Музей архитектуры, Воздвиженка', 16),
  ((select id from public.users where left(id::text,8)='5e555297' and is_test_user), 1, 'concert', 'Классика в Зале Чайковского', 'Вечер классики, разговор после. Подскажу, с чего начать, если не знаете.', 'Концертный зал им. Чайковского', 19),
  ((select id from public.users where left(id::text,8)='5e555297' and is_test_user), 2, 'coffee', 'Кофе у Консерватории', 'После уроков хочу тишины и хорошего кофе. Расскажу, почему джаз — это свобода.', 'Кофемания, Большая Никитская', 15),
  ((select id from public.users where left(id::text,8)='0b95ab52' and is_test_user), 1, 'sport', 'Петанк в Парке Горького', 'Шары мои, азарт ваш. Проигравший покупает лимонад.', 'Парк Горького, площадка для петанка', 19),
  ((select id from public.users where left(id::text,8)='0b95ab52' and is_test_user), 2, 'karaoke', 'Караоке в пятницу', 'Микрофон, плейлист нулевых и ноль разговоров о работе. Стесняться запрещено.', 'Караоке-клуб, Тверская', 23),
  ((select id from public.users where left(id::text,8)='325ab32b' and is_test_user), 1, 'bar', 'Вино на Комсомольском', 'Хорошее вино, длинный разговор. Про бизнес — только если очень попросите.', 'Винный базар, Комсомольский проспект', 20),
  ((select id from public.users where left(id::text,8)='325ab32b' and is_test_user), 2, 'food', 'Ужин в «Пушкине»', 'Классика, которую нельзя не любить. Ужин без спешки — это я умею.', 'Кафе Пушкинъ', 20),
  ((select id from public.users where left(id::text,8)='f1b8cf99' and is_test_user), 1, 'culture', 'Русский импрессионизм', 'Свет, цвет и тишина. После — нарисую вас в блокноте, если разрешите.', 'Музей русского импрессионизма', 16),
  ((select id from public.users where left(id::text,8)='f1b8cf99' and is_test_user), 2, 'coffee', 'Кофе в турке и картинки', 'Кофе по-восточному и разговор о книжках с иллюстрациями. Покажу, над чем рисую.', 'Cezve Coffee, Патриаршие', 15),
  ((select id from public.users where left(id::text,8)='d94ab3d0' and is_test_user), 1, 'walk', 'Кофейный маршрут по центру', 'Три кофейни за один круг, между ними — разговор. Я плачу за кофе, вы — честным мнением.', 'Столешников переулок', 16),
  ((select id from public.users where left(id::text,8)='d94ab3d0' and is_test_user), 2, 'food', 'Завтрак с оценкой кофе', 'Сырники, капучино (я оценю) и разговор о поездках. Откуда везти зерно — расскажу.', 'Кофемания, Кузнецкий Мост', 12),
  ((select id from public.users where left(id::text,8)='a9c57177' and is_test_user), 1, 'bar', 'Вечер в «Пропаганде»', 'Старейший клуб города, честный звук. Истории про тату — по запросу.', 'Клуб Пропаганда', 23),
  ((select id from public.users where left(id::text,8)='a9c57177' and is_test_user), 2, 'culture', 'Галереи Винзавода', 'Покажу, откуда берутся хорошие эскизы. Галереи, кофе, разговор.', 'Центр современного искусства Винзавод', 17),
  ((select id from public.users where left(id::text,8)='ea54ddec' and is_test_user), 1, 'food', 'Пицца у Бонтемпи', 'Лучшая пицца в моём рейтинге. Спорить можно, но сначала попробуйте.', 'Pinzeria by Bontempi', 20),
  ((select id from public.users where left(id::text,8)='ea54ddec' and is_test_user), 2, 'bar', 'Вечер в «Доме 12»', 'Тихий бар в переулке, хорошее вино и разговор о том, куда поехать следующим летом.', 'Дом 12, Мансуровский переулок', 21),
  ((select id from public.users where left(id::text,8)='8d8a2b6f' and is_test_user), 1, 'food', 'Ужин в «Воронеже»', 'Мясо, вино и разговор о книгах. Про суды — только смешное.', 'Ресторан Воронеж', 20),
  ((select id from public.users where left(id::text,8)='8d8a2b6f' and is_test_user), 2, 'culture', 'Исторический музей', 'Любимые залы без экскурсовода. Потом кофе на Никольской.', 'Государственный исторический музей', 15),
  ((select id from public.users where left(id::text,8)='0d34e4ed' and is_test_user), 1, 'walk', 'Сосны Серебряного бора', 'Вода, сосны и ноль уведомлений. Разговор — аналоговый.', 'Серебряный бор', 17),
  ((select id from public.users where left(id::text,8)='0d34e4ed' and is_test_user), 2, 'cinema', 'Кино в «Октябре»', 'Большой зал, хорошее кино. После — разберём сюжет как код.', 'Кинотеатр Октябрь', 20),
  ((select id from public.users where left(id::text,8)='0e11b250' and is_test_user), 1, 'walk', 'Царицыно по-дизайнерски', 'Парк, пруды и оранжереи. Расскажу, как это спроектировано и почему работает.', 'Музей-заповедник Царицыно', 17),
  ((select id from public.users where left(id::text,8)='0e11b250' and is_test_user), 2, 'coffee', 'Кофе среди растений', 'Кофе, зелень вокруг и разговор о том, что вырастет у вас на балконе.', 'Кафе в «Аптекарском огороде»', 14),
  ((select id from public.users where left(id::text,8)='54d6ed32' and is_test_user), 1, 'bar', 'Пятница в Simach', 'Танцпол, хорошие коктейли. Микрофон не нужен — тут я просто гость.', 'Simach в Недальнем', 23),
  ((select id from public.users where left(id::text,8)='54d6ed32' and is_test_user), 2, 'cinema', 'Комедия в «Звезде»', 'Маленький зал, хорошая комедия. Смеюсь громко — предупреждаю.', 'Кинотеатр Звезда, Земляной Вал', 20),
  ((select id from public.users where left(id::text,8)='29f849b0' and is_test_user), 1, 'walk', 'Басманный: дома, которые спас', 'Покажу здания, которые восстанавливал, и те, что мечтаю спасти.', 'Покровка, Басманный район', 18),
  ((select id from public.users where left(id::text,8)='29f849b0' and is_test_user), 2, 'coffee', 'Кофе в трамвайном депо', 'Фудмолл в старом депо — сам объект стоит разговора. Кофе там тоже хороший.', 'Депо, Лесная улица', 14),
  ((select id from public.users where left(id::text,8)='93de022b' and is_test_user), 1, 'sport', 'Пробежка без телефонов', 'Лёгкие 5 км, разговорный темп. После — кофе, телефоны в карманах.', 'Парк Горького, набережная', 9),
  ((select id from public.users where left(id::text,8)='93de022b' and is_test_user), 2, 'coffee', 'Кофе без ноутбуков', 'Два часа живого разговора, ноутбуки дома. Учусь не работать — присоединяйтесь.', 'Jeffrey''s Coffee, Маросейка', 15),
  ((select id from public.users where left(id::text,8)='69980b16' and is_test_user), 1, 'bar', 'Пинта в «Джоне Донне»', 'Пинта, матч на экране и разговор не о работе. Мосты обсудим, если спросите.', 'Паб Джон Донн, Большая Никитская', 21),
  ((select id from public.users where left(id::text,8)='69980b16' and is_test_user), 2, 'concert', 'Рок в «Урбане»', 'Живой звук, стоячие места. Беру два билета.', 'Клуб Урбан', 21),
  ((select id from public.users where left(id::text,8)='5a926301' and is_test_user), 1, 'bar', 'Натуральное вино', 'Честный разговор и бокал под настроение — подберу.', 'Big Wine Freaks', 20),
  ((select id from public.users where left(id::text,8)='5a926301' and is_test_user), 2, 'culture', 'Искусство и бокал', 'ГЭС-2, кофе и немного вина после. Расскажу, как сомелье смотрит на картины.', 'Дом культуры ГЭС-2', 16),
  ((select id from public.users where left(id::text,8)='b4f0a147' and is_test_user), 1, 'cinema', 'Кино под открытым небом', 'Летний кинотеатр в парке. Разберём кадры как оператор — если захотите.', 'Garage Screen, Парк Горького', 20),
  ((select id from public.users where left(id::text,8)='b4f0a147' and is_test_user), 2, 'walk', 'Фотопрогулка по Тверскому', 'Лучший свет — вечером. Камера со мной, но можно и без.', 'Тверской бульвар', 19),
  ((select id from public.users where left(id::text,8)='02ed9c52' and is_test_user), 1, 'sport', 'Скейт на набережной', 'Научу стоять на доске — на асфальте тоже. Падать будем красиво.', 'Крымская набережная, скейт-площадка', 19),
  ((select id from public.users where left(id::text,8)='02ed9c52' and is_test_user), 2, 'walk', 'Закат в Строгинской пойме', 'Вода, закат и разговор о горах. Покажу, где катаюсь летом.', 'Строгинская пойма', 18),
  ((select id from public.users where left(id::text,8)='f24d5651' and is_test_user), 1, 'food', 'Завтрак на Петроградке', 'Знаю, где на Петроградке лучшие завтраки. Кофе проверю лично — профессиональная привычка.', 'Кафе Щелкунчик, Петроградская', 12),
  ((select id from public.users where left(id::text,8)='f24d5651' and is_test_user), 2, 'culture', 'Современное в «Эрарте»', 'Современное искусство и кофе в их кафе. Обсудим, что понравилось.', 'Музей Эрарта', 16),
  ((select id from public.users where left(id::text,8)='61bd3c7a' and is_test_user), 1, 'walk', 'Петербург Достоевского', 'Тихие набережные без толп. Расскажу, где жили герои книг, которые читаем с детьми.', 'Набережная канала Грибоедова', 18),
  ((select id from public.users where left(id::text,8)='61bd3c7a' and is_test_user), 2, 'coffee', 'Кофе в «Подписных»', 'Книжный с кофейней — моё идеальное место. Найдём книгу друг другу.', 'Подписные издания, Литейный', 15),
  ((select id from public.users where left(id::text,8)='ba499f0a' and is_test_user), 1, 'sport', 'Пробежка по Фонтанке', 'Лёгкий темп, 5 км. После — завтрак, счёт пополам.', 'Набережная Фонтанки', 9),
  ((select id from public.users where left(id::text,8)='ba499f0a' and is_test_user), 2, 'coffee', 'Завтрак оптимиста', 'Кофе, круассан и планы на поездки. Обещаю не считать ваши расходы.', 'Буше, Рубинштейна', 14),
  ((select id from public.users where left(id::text,8)='551df643' and is_test_user), 1, 'cinema', 'Кино на «Ленфильме»', 'Авторское кино и разговор о сценариях. Я редактор — люблю ловить дыры в сюжете.', 'Кинозал «Ленфильм»', 20),
  ((select id from public.users where left(id::text,8)='551df643' and is_test_user), 2, 'bar', 'Вино и книги в «Цветочках»', 'Бокал вина и разговор о книгах. Принесу одну — отдам, если понравитесь.', 'Бар Цветочки, Некрасова', 21),
  ((select id from public.users where left(id::text,8)='8a9421e2' and is_test_user), 1, 'karaoke', 'Караоке на Думской', 'Пою плохо, зато смело. Дуэт обязателен.', 'Караоке-бар, Думская', 23),
  ((select id from public.users where left(id::text,8)='8a9421e2' and is_test_user), 2, 'coffee', 'Кофе на Некрасова', 'Оденусь смело, приду вовремя. Расскажу, что вам идёт — честно.', 'Civil Coffee Bar, Некрасова', 15),
  ((select id from public.users where left(id::text,8)='05834b07' and is_test_user), 1, 'concert', 'Лайв в Aurora Hall', 'Живой звук, стоячий партер. Танцую — предупреждаю.', 'Aurora Concert Hall', 20),
  ((select id from public.users where left(id::text,8)='05834b07' and is_test_user), 2, 'cinema', 'Кино в «Англетере»', 'Маленький зал, авторское кино. После — коктейль рядом.', 'Кинотеатр Англетер', 20),
  ((select id from public.users where left(id::text,8)='95da511a' and is_test_user), 1, 'food', 'Хинкали на Рубинштейна', 'Знаю, где лучшие хинкали на улице. Покажу — и проверю, умеете ли их есть.', 'Пхали-Хинкали, Рубинштейна', 20),
  ((select id from public.users where left(id::text,8)='95da511a' and is_test_user), 2, 'bar', 'Тихий бар после смены', 'Тихий бар после громкой смены. Хороший разговор — лучший коктейль.', 'Apotheke Bar', 22),
  ((select id from public.users where left(id::text,8)='b9fd89db' and is_test_user), 1, 'culture', 'Эрмитаж за два часа', 'Три зала, которые стоит увидеть, и ноль очередей — знаю вход. После — кофе.', 'Эрмитаж', 14),
  ((select id from public.users where left(id::text,8)='b9fd89db' and is_test_user), 2, 'walk', 'Закат на Дворцовой набережной', 'Вода, закат и разговор о кино. Билеты из «Авроры» покажу.', 'Дворцовая набережная', 19),
  ((select id from public.users where left(id::text,8)='75602b1e' and is_test_user), 1, 'coffee', 'Пирожное на Невском', 'Утро после невест — заслужила пирожное и разговор не про тушь.', 'Север-Метрополь, Невский', 15),
  ((select id from public.users where left(id::text,8)='75602b1e' and is_test_user), 2, 'cinema', 'Мелодрама в «Великане»', 'Красивый зал в Александровском парке. Выбираю мелодраму, не спорьте.', 'Кинотеатр «Великан Парк»', 20),
  ((select id from public.users where left(id::text,8)='ee66e43c' and is_test_user), 1, 'coffee', 'Какао у Джо', 'Какао, плейлист и разговор. Дикцию не исправляю — обещаю.', 'Знакомьтесь, Джо', 15),
  ((select id from public.users where left(id::text,8)='ee66e43c' and is_test_user), 2, 'walk', 'Таврический на двоих', 'Тихий сад, пруд и мой плейлист. Один наушник — вам.', 'Таврический сад', 18),
  ((select id from public.users where left(id::text,8)='f6b8c072' and is_test_user), 1, 'culture', 'Скелет кита и не только', 'Покажу, почему Зоологический музей — это красиво. Потом уток кормить.', 'Зоологический музей', 14),
  ((select id from public.users where left(id::text,8)='f6b8c072' and is_test_user), 2, 'walk', 'Оранжереи Ботанического', 'Редкие растения и тёплые оранжереи. Расскажу, что из этого съедобно. Шутка. Почти.', 'Ботанический сад Петра Великого', 16),
  ((select id from public.users where left(id::text,8)='d7bb221c' and is_test_user), 1, 'bar', 'Вечер в Union', 'Громкая музыка, хорошие коктейли. Подпеваю даже бармену.', 'Union Bar, Литейный', 22),
  ((select id from public.users where left(id::text,8)='d7bb221c' and is_test_user), 2, 'culture', 'Выставка в «Манеже»', 'Новая экспозиция и разговор о визуале. Покажу, как двигаю картинки.', 'ЦВЗ «Манеж»', 16),
  ((select id from public.users where left(id::text,8)='330e943b' and is_test_user), 1, 'coffee', 'Чужие торты на пробу', 'Профессиональная дегустация чужих десертов. Скажу честно, чей лучше.', 'Кондитерская Вольчек', 15),
  ((select id from public.users where left(id::text,8)='330e943b' and is_test_user), 2, 'food', 'Ужин в «Банщиках»', 'Русская кухня в современном прочтении. Десерт оценю как профессионал — честно.', 'Банщики, Дегтярная', 20),
  ((select id from public.users where left(id::text,8)='c2a87246' and is_test_user), 1, 'bar', 'Бокал без метрик', 'Вино и разговор без цифр. Калории не считаю, обещала.', 'Винный шкаф, Рубинштейна', 21),
  ((select id from public.users where left(id::text,8)='c2a87246' and is_test_user), 2, 'coffee', 'Долгий завтрак в Bonch', 'Завтраки там как я люблю — долгие. Расскажу, куда полечу в отпуск.', 'Bonch, Большая Морская', 12),
  ((select id from public.users where left(id::text,8)='b182314b' and is_test_user), 1, 'sport', 'Час в седле', 'Посажу в седло за час — проверено на новичках. Лошадь добрая, я строгая.', 'Конный клуб, Пушкин', 12),
  ((select id from public.users where left(id::text,8)='b182314b' and is_test_user), 2, 'walk', 'Павловский парк и белки', 'Самый большой пейзажный парк и мой любимый. Белки — бонус.', 'Павловский парк', 13),
  ((select id from public.users where left(id::text,8)='7c4291bf' and is_test_user), 1, 'food', 'Завтрак после ночной смены', 'Яичница, кофе и хороший разговор. Шутки — мои.', 'Мечтатели, Фонтанка', 13),
  ((select id from public.users where left(id::text,8)='7c4291bf' and is_test_user), 2, 'walk', 'Фонтанка до Летнего сада', 'Пройдёмся вдоль воды. Знаю, где по пути самый вкусный кофе.', 'Набережная Фонтанки', 18),
  ((select id from public.users where left(id::text,8)='695f146d' and is_test_user), 1, 'walk', 'Ветер в парке 300-летия', 'Залив, ветер и разговор о чём угодно, кроме тренировок. Ну почти.', 'Парк 300-летия Петербурга', 18),
  ((select id from public.users where left(id::text,8)='695f146d' and is_test_user), 2, 'food', 'Ужин после тренировки', 'Местные продукты и честный разговор. Калории не считаю — выходной.', 'Ресторан Кококо', 20),
  ((select id from public.users where left(id::text,8)='be38c5ed' and is_test_user), 1, 'travel', 'На яхте в Кронштадт', 'Яхта, залив и форты. Если укачивает — возьму имбирь.', 'Кронштадт', 11),
  ((select id from public.users where left(id::text,8)='be38c5ed' and is_test_user), 2, 'bar', 'Про Балтику без романтики', 'На суше теряюсь, в баре — нет. Расскажу, как на самом деле ходят под парусом.', 'Бар Хроники, Некрасова', 21),
  ((select id from public.users where left(id::text,8)='62f8075a' and is_test_user), 1, 'walk', 'Дюны Сестрорецка', 'Залив, дюны и честный разговор. Электричка — часть приключения.', 'Сестрорецк, Разлив', 13),
  ((select id from public.users where left(id::text,8)='62f8075a' and is_test_user), 2, 'culture', 'Музей связи для гуманитариев', 'Будущий энергетик ведёт в музей техники. Обещаю — интересно всем.', 'Музей связи им. Попова', 15),
  ((select id from public.users where left(id::text,8)='623aac6b' and is_test_user), 1, 'walk', 'Набережная с персиком', 'Мой выходной: вода, персик и планы. Поделюсь и тем, и другим.', 'Набережная Лейтенанта Шмидта', 19),
  ((select id from public.users where left(id::text,8)='623aac6b' and is_test_user), 2, 'coffee', 'Кофе, который варил не я', 'В выходной ем то, что готовят другие. Обсудим, где они ошибаются.', 'Буше, Васильевский остров', 14),
  ((select id from public.users where left(id::text,8)='4ac48a83' and is_test_user), 1, 'walk', 'Петергоф на Defender', 'Доедем на старом Defender, дальше пешком. Фонтаны и дорога под плейлист.', 'Петергоф', 13),
  ((select id from public.users where left(id::text,8)='4ac48a83' and is_test_user), 2, 'coffee', 'Кофе и разговор о дорогах', 'Покажу фото Defender — он фотогеничнее меня. Кофе — за мной.', 'Surf Coffee, Садовая', 15),
  ((select id from public.users where left(id::text,8)='ebac1cc1' and is_test_user), 1, 'walk', 'Петропавловка медленно', 'Без гида. Расскажу, из чего сделаны двери собора — столяр не может иначе.', 'Петропавловская крепость', 18),
  ((select id from public.users where left(id::text,8)='ebac1cc1' and is_test_user), 2, 'culture', 'Дерево и резьба у Штиглица', 'Интерьеры и резьба. Там понятно, зачем я делаю мебель руками.', 'Музей Академии Штиглица', 15),
  ((select id from public.users where left(id::text,8)='37d3f6e6' and is_test_user), 1, 'bar', 'Настолки и сидр', 'Принесу игру на двоих. Проигравший покупает сидр.', 'Сидрерия, Рубинштейна', 21),
  ((select id from public.users where left(id::text,8)='37d3f6e6' and is_test_user), 2, 'walk', 'Белки Удельного парка', 'Тихий парк и разговор о том, во что вы играли в детстве.', 'Удельный парк', 18),
  ((select id from public.users where left(id::text,8)='4eadc113' and is_test_user), 1, 'walk', 'Дачи Каменного острова', 'Мосты, дачи и тишина в центре города. Покажу, откуда начинается мой Север.', 'Каменный остров', 18),
  ((select id from public.users where left(id::text,8)='4eadc113' and is_test_user), 2, 'culture', 'Музей Арктики', 'Мой любимый музей. Расскажу, что в экспозиции правда, а что — романтика.', 'Музей Арктики и Антарктики', 15),
  ((select id from public.users where left(id::text,8)='db3e6c3b' and is_test_user), 1, 'bar', 'Звук в баре — проверю', 'Хороший звук даже в баре — оценю. Расскажу, как делают концерты.', 'Дорогая, я перезвоню', 22),
  ((select id from public.users where left(id::text,8)='db3e6c3b' and is_test_user), 2, 'culture', 'Музей звука', 'Маленький музей, где можно трогать инструменты. Покажу, как устроен звук.', 'Музей звука, Пушкинская 10', 16),
  ((select id from public.users where left(id::text,8)='47753929' and is_test_user), 1, 'bar', 'Крафт, который варил не я', 'Честно оценю чужое пиво. Борода в комплекте.', 'RedRum Bar', 21),
  ((select id from public.users where left(id::text,8)='47753929' and is_test_user), 2, 'walk', 'История города через пиво', 'После смены хочу воздуха. Расскажу историю Петербурга через пиво — это реально.', 'Кронверкская набережная', 18)
on conflict (owner_id, seq) do nothing;

-- Motor: rotasyon adımı eklendi (gövde = ops/simulate_test_liveliness.sql)
create or replace function public.simulate_test_liveliness()
returns table(refreshed_invitations int, seeded_applications int, touched_users int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now       timestamptz := now();
  v_msk_hour  int := extract(hour from v_now at time zone 'Europe/Moscow')::int;
  -- Bypass/Mustafa hesabı: motor hiçbir yazmada bu kullanıcıya dokunmaz
  v_bypass    uuid := '279e44e0-f09e-4b31-ad20-94966aa6f6bb';
  r           record;
  v_created   timestamptz;
  v_expires   timestamptz;
  n_apps      int;
  v_refreshed int := 0;
  v_apps      int := 0;
  v_touched   int := 0;
  -- İçerik rotasyonu (19.08.2026): kişi başına birden çok davet varyantı
  v_nvar      int;
  v_cur       int;
  v_next      int;
  v_var       record;
  v_evbase    timestamptz;
  v_evdate    timestamptz;
begin
  -- ── 1) Davet rebirth: dolan kart ANINDA yenilenir (v2 — ölü bekleme yok) ──
  for r in
    select u.id as user_id, u.gender, u.city_id,
           i.id as inv_id, i.status as inv_status, i.expires_at, i.event_date
    from public.users u
    left join lateral (
      select id, status, expires_at, event_date
      from public.invitations
      where owner_id = u.id
      order by expires_at desc
      limit 1
    ) i on true
    where u.is_test_user = true
      and u.id <> v_bypass
      and u.is_deleted = false
      and u.banned = false
      and i.id is not null                -- davetsiz test kullanıcısını fonksiyon YARATMAZ
                                          -- (ilk davet add-test-user.sh'ın işi)
  loop
    -- Aktif ve süresi dolmamış davet varsa dokunma.
    -- Expiry-race fix: 2 dk tolerans — cron koşarken dolmak üzere olanlar da yenilenir.
    if r.inv_status = 'active' and r.expires_at > v_now + interval '2 minutes' then
      continue;
    end if;

    -- Rebirth damgaları: hep "az önce / 1 saat önce" hissi + doğal geri sayım
    v_created := v_now - (random() * interval '90 minutes');
    v_expires := v_created + interval '20 hours' + (random() * interval '6 hours');

    update public.invitations i
    set status     = 'active',
        created_at = v_created,
        expires_at = v_expires,
        -- event_date geçmişte/expiry içinde kalmasın: saat korunur, gün ileri itilir
        event_date = case
          when i.event_date > v_expires then i.event_date
          else i.event_date
             + (ceil(extract(epoch from (v_expires - i.event_date)) / 86400.0)::int
                * interval '1 day')
        end
        -- selection_deadline'a DOKUNULMAZ (D1 teyitli 10.07): job 1 onu yalnız
        -- active→selecting geçişinde expires_at+48h yapar; aktif davette inert.
        -- selecting/closed'a düşmüş test daveti bu update ile zaten active'e döner.
    where i.id = r.inv_id
      and exists (select 1 from public.users ou
                  where ou.id = i.owner_id and ou.is_test_user = true);  -- çifte guard
    v_refreshed := v_refreshed + 1;

    -- Eski başvuruları sil — TEST ve GERÇEK kullanıcılarınki birlikte (19.08.2026,
    -- Mustafa kararı). Gerekçe: gerçek akışta dolan matchsiz ilan closed→SİLİNİR
    -- ve başvurular CASCADE ile gider; yeniden doğan test kartı "yeni ilan"dır,
    -- gerçek kullanıcının eski başvurusu aynı satırda sonsuza dek 'pending'
    -- kalıyordu (Başvurularım'da 21 gün "Bekliyor" = sahte sinyal). selected/
    -- accepted ASLA silinmez (test sahibi seçmez; olası match korunur).
    delete from public.applications a
    where a.invitation_id = r.inv_id
      and a.status in ('pending', 'withdrawn', 'rejected', 'expired');

    -- İÇERİK ROTASYONU (19.08.2026, Mustafa kararı): test kartı yeniden doğarken
    -- kişinin sıradaki davet varyantını alır (kategori/başlık/açıklama/mekân/saat)
    -- → "aynı kişi aynı kafede her gün" sahte sinyali kalkar. Varyant yoksa
    -- (ör. Демо) içerik aynen kalır. Sıra: test_rotation_state (kişi başına seq).
    select count(*) into v_nvar
      from public.test_invitation_variants where owner_id = r.user_id;
    if v_nvar > 1 then
      select seq into v_cur from public.test_rotation_state where owner_id = r.user_id;
      v_next := (coalesce(v_cur, 0) + 1) % v_nvar;
      select * into v_var
        from public.test_invitation_variants
       where owner_id = r.user_id and seq = v_next;
      if found then
        -- event_date: expires+1h'den sonraki ilk "varyant saati" (MSK) — süre kuralı
        -- expires_at ≤ event_date − 1h (17.08) korunur.
        v_evbase := v_expires + interval '1 hour';
        v_evdate := (date_trunc('day', v_evbase at time zone 'Europe/Moscow')
                     + make_interval(hours => v_var.ev_hour)) at time zone 'Europe/Moscow';
        if v_evdate < v_evbase then v_evdate := v_evdate + interval '1 day'; end if;

        update public.invitations i
           set category    = v_var.category,
               title       = v_var.title,
               description = v_var.description,
               venue_name  = v_var.venue_name,
               event_date  = v_evdate
         where i.id = r.inv_id
           and exists (select 1 from public.users ou
                       where ou.id = i.owner_id and ou.is_test_user = true);  -- çifte guard

        insert into public.test_rotation_state (owner_id, seq)
        values (r.user_id, v_next)
        on conflict (owner_id) do update set seq = excluded.seq, updated_at = now();
      end if;
    end if;

    -- 0–4 taze test başvuranı ek (aynı şehir, karşı cinsiyet, davet doğumundan sonra damga)
    n_apps := floor(random()*5)::int;
    with fresh as (
      insert into public.applications (invitation_id, applicant_id, status, created_at)
      select r.inv_id, tu.id, 'pending',
             v_created + (random() * (v_now - v_created))
      from public.users tu
      where tu.is_test_user = true
        and tu.id <> r.user_id
        and tu.id <> v_bypass
        and tu.city_id = r.city_id
        and tu.gender is distinct from r.gender
        and tu.is_deleted = false
        and tu.banned = false
      order by random()
      limit n_apps
      on conflict (invitation_id, applicant_id) do nothing
      returning applicant_id, created_at
    )
    -- Başvuranların keşfet tazeliği: last_active_at ≈ başvuru anı
    update public.users u
    set last_active_at = greatest(coalesce(u.last_active_at, f.created_at), f.created_at)
    from fresh f
    where u.id = f.applicant_id and u.is_test_user = true;

    get diagnostics n_apps = row_count;  -- update edilen başvuran sayısı
    v_apps := v_apps + n_apps;

    -- Davet sahibinin tazeliği
    update public.users
    set last_active_at = v_created + (random() * (v_now - v_created))
    where id = r.user_id and is_test_user = true;
  end loop;

  -- ── 2) Keşfet tazelik nabzı: uyanık saatlerde koşu başına 2–4 rastgele
  --       test kullanıcısına "az önce aktifti" damgası (davetten bağımsız) ──
  if v_msk_hour between 8 and 23 then
    update public.users u
    set last_active_at = v_now - (random() * interval '30 minutes')
    from (
      select id from public.users
      where is_test_user = true and id <> v_bypass
        and is_deleted = false and banned = false
      order by random()
      limit 2 + floor(random()*3)::int
    ) pick
    where u.id = pick.id;
    get diagnostics v_touched = row_count;
  end if;

  return query select v_refreshed, v_apps, v_touched;
end;
$$;

-- Kanıt sorguları (beklenen: 62 / 124 / 62 sahip ×3)
do $chk$
declare n0 int; n12 int; nown int;
begin
  select count(*) into n0  from public.test_invitation_variants where seq = 0;
  select count(*) into n12 from public.test_invitation_variants where seq in (1,2);
  select count(distinct owner_id) into nown from public.test_invitation_variants;
  raise notice 'variants seq0=% seq1-2=% owners=%', n0, n12, nown;
  if n0 <> 62 or n12 <> 124 or nown <> 62 then
    raise exception 'ROTATION SEED MISMATCH seq0=% seq12=% owners=%', n0, n12, nown;
  end if;
end $chk$;

commit;
