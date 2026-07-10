-- ============================================================================
-- Pilot 10 test kullanıcısı — ekleme (10.07.2026, Mustafa onayı: "sınırlı devam")
-- Fotolar storage'a ayrı yüklenir (test-v2/); URL'ler burada sabit.
-- ============================================================================
begin;

-- auth.users
insert into auth.users (instance_id, id, aud, role, phone, phone_confirmed_at,
                        encrypted_password, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', x.id::uuid, 'authenticated','authenticated',
       x.phone, now(), '', now() - (x.days_ago || ' days')::interval, now()
from (values
 ('8576dd53-d6d0-4c7d-b802-293214b76526','+79991112015', 18),
 ('fd0f546f-6467-4d99-aa87-7bd7ce92a2e4','+79991112006', 11),
 ('5dc4764c-f9e6-414f-8932-82f988e658e9','+79991112007', 23),
 ('ac7257c7-603c-44a2-9f2e-dc0510a8781c','+79991112008',  7),
 ('9ec3bf63-0240-407e-b6be-fd872731278a','+79991112009', 15),
 ('cfb01d32-facb-43d3-8dbc-c0444c98f8cf','+79991112010', 20),
 ('5a8c2e9c-1d27-4eb2-99bf-bf3ee0ec4bc5','+79991112011',  9),
 ('9a31b72f-23b8-45e6-afbc-6b79c222e5d3','+79991112012', 25),
 ('5a55667c-265a-4140-9b54-a65acd191a18','+79991112013',  5),
 ('e2635204-7b76-45b2-af82-27ace6b6717d','+79991112014', 13)
) as x(id, phone, days_ago);

-- public.users  (Msk=3f08d6f3-..., SPb=407e864c-...)
insert into public.users (id, phone, name, age, gender, city_id, bio, job, education,
                          language, verified, verified_at, selfie_status, is_test_user,
                          consent_given_at, consent_version, created_at, last_active_at)
select x.id::uuid, x.phone, x.nm, x.age, x.g, x.city::uuid, x.bio, x.job, x.edu,
       'ru', true, now() - (x.d || ' days')::interval, 'approved', true,
       now() - (x.d || ' days')::interval, '2026-07-08',
       now() - (x.d || ' days')::interval,
       now() - (random() * interval '6 hours')
from (values
 ('8576dd53-d6d0-4c7d-b802-293214b76526','+79991112015','Егор',28,'male','3f08d6f3-c1c1-4315-996f-4b5232441b44',
  'Дизайню днём, по вечерам варю кофе друзьям. Ценю людей, с которыми легко и без пафоса','продуктовый дизайнер',null,18),
 ('fd0f546f-6467-4d99-aa87-7bd7ce92a2e4','+79991112006','Тимур',32,'male','3f08d6f3-c1c1-4315-996f-4b5232441b44',
  'Цифры на работе, импровизация после. Джаз, бег по набережной, стейки','финансовый аналитик',null,11),
 ('5dc4764c-f9e6-414f-8932-82f988e658e9','+79991112007','Никита',25,'male','3f08d6f3-c1c1-4315-996f-4b5232441b44',
  'Снимаю город и людей. Могу показать Москву, которую вы не видели 🎥','видеограф',null,23),
 ('ac7257c7-603c-44a2-9f2e-dc0510a8781c','+79991112008','София',24,'female','3f08d6f3-c1c1-4315-996f-4b5232441b44',
  'Живу в сторис, отдыхаю в кино. Полнометражки — только на большом экране!','SMM-специалист',null,7),
 ('9ec3bf63-0240-407e-b6be-fd872731278a','+79991112009','Вера',29,'female','3f08d6f3-c1c1-4315-996f-4b5232441b44',
  'Улыбки — моя профессия 🙂 После работы — выставки и длинные прогулки','врач-стоматолог',null,15),
 ('cfb01d32-facb-43d3-8dbc-c0444c98f8cf','+79991112010','Глеб',30,'male','407e864c-f039-44d8-86ef-c2606fb07c43',
  'Строю корабли, хожу под парусом. Покажу Питер с воды','инженер-судостроитель',null,20),
 ('5a8c2e9c-1d27-4eb2-99bf-bf3ee0ec4bc5','+79991112011','Марк',27,'male','407e864c-f039-44d8-86ef-c2606fb07c43',
  'Кормлю людей и радуюсь. Дегустации, рынки, эксперименты на кухне','шеф-повар',null,9),
 ('9a31b72f-23b8-45e6-afbc-6b79c222e5d3','+79991112012','Степан',34,'male','407e864c-f039-44d8-86ef-c2606fb07c43',
  'Каждый день вожу людей по Неве, а сам всё ещё не нагулялся по городу','капитан речного трамвайчика',null,25),
 ('5a55667c-265a-4140-9b54-a65acd191a18','+79991112013','Лиза',23,'female','407e864c-f039-44d8-86ef-c2606fb07c43',
  'Пишу код, читаю пьесы. Странное сочетание? Приходите обсудить','студентка','ИТМО',5),
 ('e2635204-7b76-45b2-af82-27ace6b6717d','+79991112014','Кира',26,'female','407e864c-f039-44d8-86ef-c2606fb07c43',
  'Леплю кружки и тарелки, веду мастер-классы по керамике. Лучший вечер — чай и разговоры по душам','керамистка',null,13)
) as x(id, phone, nm, age, g, city, bio, job, edu, d);

-- user_photos (test-v2/<slug>.jpg — yükleme scripti aynı adları kullanır)
insert into public.user_photos (user_id, url, is_primary, is_selfie, moderation_status, order_index)
select x.id::uuid,
       'https://soulchoice.app/storage/v1/object/public/profile-photos/test-v2/' || x.f,
       true, false, 'approved', 0
from (values
 ('8576dd53-d6d0-4c7d-b802-293214b76526','p01_egor.jpg'),
 ('fd0f546f-6467-4d99-aa87-7bd7ce92a2e4','p02_timur_v3.jpg'),
 ('5dc4764c-f9e6-414f-8932-82f988e658e9','p03_nikita.jpg'),
 ('ac7257c7-603c-44a2-9f2e-dc0510a8781c','p04_sofia.jpg'),
 ('9ec3bf63-0240-407e-b6be-fd872731278a','p05_vera.jpg'),
 ('cfb01d32-facb-43d3-8dbc-c0444c98f8cf','p06_gleb.jpg'),
 ('5a8c2e9c-1d27-4eb2-99bf-bf3ee0ec4bc5','p07_mark.jpg'),
 ('9a31b72f-23b8-45e6-afbc-6b79c222e5d3','p08_stepan.jpg'),
 ('5a55667c-265a-4140-9b54-a65acd191a18','p09_liza.jpg'),
 ('e2635204-7b76-45b2-af82-27ace6b6717d','p10_kira.jpg')
) as x(id, f);

-- 6 davet
insert into public.invitations (owner_id, flow_type, category, title, venue_name,
                                event_date, city_id, slots_total, status, created_at, expires_at)
select x.owner::uuid, x.fl, x.cat, x.ttl, x.ven,
       date_trunc('day', now()) + interval '1 day' + (x.h || ' hours')::interval,
       x.city::uuid, 1, 'active',
       now() - (random() * interval '90 minutes'),
       now() + interval '20 hours' + (random() * interval '6 hours')
from (values
 ('8576dd53-d6d0-4c7d-b802-293214b76526','invite','coffee','Флэт уайт в «Чёрном»','Кооператив Чёрный',11,'3f08d6f3-c1c1-4315-996f-4b5232441b44'),
 ('fd0f546f-6467-4d99-aa87-7bd7ce92a2e4','invite','food','Гастротур по «Депо»','Депо, Лесная',20,'3f08d6f3-c1c1-4315-996f-4b5232441b44'),
 ('ac7257c7-603c-44a2-9f2e-dc0510a8781c','request','cinema','Премьера в «Октябре»','КАРО 11 Октябрь',20,'3f08d6f3-c1c1-4315-996f-4b5232441b44'),
 ('cfb01d32-facb-43d3-8dbc-c0444c98f8cf','invite','walk','Закат на Васильевском','Васильевский остров',21,'407e864c-f039-44d8-86ef-c2606fb07c43'),
 ('5a8c2e9c-1d27-4eb2-99bf-bf3ee0ec4bc5','invite','food','Сет в Duo Gastrobar','Duo Gastrobar',19,'407e864c-f039-44d8-86ef-c2606fb07c43'),
 ('5a55667c-265a-4140-9b54-a65acd191a18','request','theater','Вечер в БДТ','БДТ им. Товстоногова',19,'407e864c-f039-44d8-86ef-c2606fb07c43')
) as x(owner, fl, cat, ttl, ven, h, city);

update public.invitations i set description = d.dsc
from (values
 ('8576dd53-d6d0-4c7d-b802-293214b76526','Лучший кофе города, проверено. Приглашаю на чашку и разговор без спешки.'),
 ('fd0f546f-6467-4d99-aa87-7bd7ce92a2e4','Пройдёмся по корнерам, соберём идеальный ужин из пяти кухонь.'),
 ('ac7257c7-603c-44a2-9f2e-dc0510a8781c','Очень жду новую премьеру на Новом Арбате. Кто составит компанию?'),
 ('cfb01d32-facb-43d3-8dbc-c0444c98f8cf','Стрелка, набережные и лучший вид на разводку мостов. Маршрут за мной.'),
 ('5a8c2e9c-1d27-4eb2-99bf-bf3ee0ec4bc5','Знаю шефа, забронирую лучшие места. Ужин, о котором вы будете рассказывать.'),
 ('5a55667c-265a-4140-9b54-a65acd191a18','Мечтаю на новую постановку. Ищу того, кто разделит антракт и впечатления.')
) as d(owner, dsc)
where i.owner_id = d.owner::uuid and i.created_at > now() - interval '2 hours';

commit;

-- Kanıt
select c.name, u.gender, count(*) from public.users u join public.cities c on c.id=u.city_id
where u.is_test_user group by 1,2 order by 1,2;
