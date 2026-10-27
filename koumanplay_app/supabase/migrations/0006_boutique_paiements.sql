-- Boutique et paiements en ligne (GeniusPay : Wave, Orange Money, MTN MoMo, carte).
-- À lancer dans l'éditeur SQL de Supabase. Relançable sans risque.
--
-- Principe : l'app demande un paiement à la fonction create-payment, le joueur
-- paie sur la page GeniusPay, puis GeniusPay prévient la fonction
-- geniuspay-webhook. Seules ces fonctions (clé service_role, côté serveur)
-- écrivent les paiements et les crédits ; le joueur ne fait que les lire et
-- récupérer ce qui lui revient (claim_wallet_credits).

-- Produits vendus contre de l'argent. Prix en francs CFA, modifiables ici.
create table if not exists public.shop_products (
  id text primary key,
  kind text not null check (kind in ('cauris', 'premium')),
  title text not null,
  description text not null default '',
  price_xof integer not null check (price_xof >= 200),   -- minimum GeniusPay
  cauris integer not null default 0,                       -- pack de cauris
  premium_days integer not null default 0,                 -- KoumanPlay+
  active boolean not null default true,
  sort integer not null default 0
);

insert into public.shop_products (id, kind, title, description, price_xof, cauris, premium_days, sort) values
  ('cauris-100', 'cauris', 'Petit sac de cauris', '100 cauris', 500, 100, 0, 1),
  ('cauris-250', 'cauris', 'Sac de cauris', '250 cauris (25 offerts)', 1000, 250, 0, 2),
  ('cauris-700', 'cauris', 'Grand sac de cauris', '700 cauris (200 offerts)', 2500, 700, 0, 3),
  ('plus-30', 'premium', 'KoumanPlay+ · 30 jours', 'Énergie illimitée et coffres doublés pendant 30 jours', 1000, 0, 30, 4)
on conflict (id) do nothing;

-- Un paiement demandé par un joueur. Écrit uniquement par les fonctions.
create table if not exists public.payments (
  reference text primary key,                 -- référence GeniusPay (MTX-...)
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null references public.shop_products (id),
  amount_xof integer not null,
  payment_method text,
  status text not null default 'pending',     -- pending, completed, failed, cancelled, expired, refunded
  credited boolean not null default false,    -- produit déjà livré au joueur
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists payments_user on public.payments (user_id, created_at desc);

-- Cauris payés, en attente d'être récupérés par l'app du joueur.
create table if not exists public.wallet_credits (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  cauris integer not null check (cauris > 0),
  payment_reference text not null unique references public.payments (reference),
  created_at timestamptz not null default now(),
  claimed_at timestamptz
);

-- Abonnement KoumanPlay+ : date de fin.
create table if not exists public.premium (
  user_id uuid primary key references auth.users (id) on delete cascade,
  premium_until timestamptz not null
);

alter table public.shop_products enable row level security;
alter table public.payments enable row level security;
alter table public.wallet_credits enable row level security;
alter table public.premium enable row level security;

drop policy if exists "lecture publique" on public.shop_products;
create policy "lecture publique" on public.shop_products for select using (active);
drop policy if exists "mes paiements" on public.payments;
create policy "mes paiements" on public.payments for select using (auth.uid() = user_id);
drop policy if exists "mes crédits" on public.wallet_credits;
create policy "mes crédits" on public.wallet_credits for select using (auth.uid() = user_id);
drop policy if exists "mon abonnement" on public.premium;
create policy "mon abonnement" on public.premium for select using (auth.uid() = user_id);

grant select on public.shop_products to anon, authenticated;
grant select on public.payments, public.wallet_credits, public.premium to authenticated;

-- Le joueur récupère ses cauris payés (une seule fois) et sa date KoumanPlay+.
create or replace function public.claim_wallet_credits()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  total integer;
  until timestamptz;
begin
  if auth.uid() is null then
    raise exception 'non connecté';
  end if;
  with claimed as (
    update public.wallet_credits
       set claimed_at = now()
     where user_id = auth.uid() and claimed_at is null
    returning cauris
  )
  select coalesce(sum(cauris), 0) into total from claimed;
  select premium_until into until from public.premium where user_id = auth.uid();
  return jsonb_build_object('cauris', total, 'premium_until', until);
end;
$$;

revoke all on function public.claim_wallet_credits() from public;
grant execute on function public.claim_wallet_credits() to authenticated;
