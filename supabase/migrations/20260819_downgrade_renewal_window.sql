-- 19.08.2026 — Yenileme günü "free düşüş penceresi" düzeltmesi (senaryo denetimi bulgusu).
-- Sorun: downgrade_expired_premium (pg_cron, her saat :25) premium_until geçen aktif
-- kullanıcıyı hemen 'free' yapıyordu; billing-cron FAZ B çekimi ise günde 1 kez (07:25 UTC)
-- ve yalnız next_billing_at <= now() olunca → her döngüde abone ~13–24 saat premium'suz
-- kalıyor, bu pencerede can_user_apply sayaç moduna düşüyor, başvuru hak yakıyor,
-- paywall'da "Оформить" 409 already_subscribed veriyor. Çekim sonrası tekrar active.
-- Düzeltme: yenileme çekimi bekleyen aboneyi (active + auto_renew + tochka_subscription_id,
-- next_billing_at son 48 saat içinde) düşürme; çekim başarısız olursa past_due+grace
-- istisnası zaten var; 48 saat geçtiği hâlde ne çekim ne past_due varsa (charge_unknown
-- vb.) eski davranış (free) devreye girer.
-- Prod: supabase_admin ile koş. Tek kaynak: bu dosya (önceki: 20260711_f2_billing_cron.sql).

create or replace function public.downgrade_expired_premium()
returns void
language sql
as $$
  update users u
     set subscription_status = 'free'
   where u.subscription_status = 'active'
     and u.premium_until is not null
     and u.premium_until < now()
     -- past_due + grace: KARAR 2 (premium grace boyunca açık)
     and not exists (
       select 1 from subscriptions s
        where s.user_id = u.id
          and s.status = 'past_due'
          and s.grace_until is not null
          and s.grace_until > now()
     )
     -- 19.08: yenileme çekimi sırada — günlük FAZ B gelene kadar düşürme
     and not exists (
       select 1 from subscriptions s
        where s.user_id = u.id
          and s.status = 'active'
          and s.auto_renew
          and s.tochka_subscription_id is not null
          and s.next_billing_at is not null
          and s.next_billing_at > now() - interval '48 hours'
     );
$$;
