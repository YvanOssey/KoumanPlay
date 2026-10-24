-- KoumanPlay V1 : schéma Supabase.
-- À exécuter dans Supabase > SQL Editor (ou `supabase db push`).
-- Pré-requis : Authentication > Providers > activer "Anonymous sign-ins" et "Email".

-- ---------------------------------------------------------------------------
-- Contenu (lecture publique, édition via le dashboard Supabase)
-- ---------------------------------------------------------------------------

create table public.cultural_groups (
  id text primary key,
  name text not null,
  available boolean not null default false,
  sort int not null default 0
);

create table public.categories (
  id text primary key,
  name text not null,
  description text not null default '',
  color text not null default '#5B2EFF',
  image text,
  available boolean not null default false,
  sort int not null default 0
);

create table public.levels (
  id text primary key,
  category_id text not null references public.categories(id),
  sort int not null,
  title text not null,
  pass_ratio numeric not null default 0.6
);

create table public.activities (
  id text primary key,
  level_id text not null references public.levels(id),
  proverb text not null,
  original text,
  language text,
  question text not null,
  answers jsonb not null,             -- ["réponse A", "réponse B", ...]
  correct int not null,               -- index de la bonne réponse (0 = A)
  explanation text not null default '',
  xp int not null default 20,
  validated boolean not null default false,  -- validé par le référent culturel
  validated_by text,
  published boolean not null default true,
  sort int not null default 0,
  check (correct >= 0 and correct < jsonb_array_length(answers))
);

create table public.challenges (
  id text primary key,
  role text not null default 'all' check (role in ('jeune', 'senior', 'all')),
  unlock_after_level text references public.levels(id),
  title text not null,
  description text not null default '',
  reward_xp int not null default 100,
  duration_min int not null default 15,
  difficulty text not null default 'Facile',
  steps jsonb not null,               -- ["étape 1", "étape 2", ...]
  note_prompt text not null default 'Ce que tu as appris',
  published boolean not null default true,
  sort int not null default 0
);

alter table public.cultural_groups enable row level security;
alter table public.categories enable row level security;
alter table public.levels enable row level security;
alter table public.activities enable row level security;
alter table public.challenges enable row level security;

create policy "lecture publique" on public.cultural_groups for select using (true);
create policy "lecture publique" on public.categories for select using (true);
create policy "lecture publique" on public.levels for select using (true);
create policy "lecture publique" on public.activities for select using (published);
create policy "lecture publique" on public.challenges for select using (published);

-- ---------------------------------------------------------------------------
-- Joueurs : une ligne par compte (anonyme ou email), état complet en JSON.
-- ---------------------------------------------------------------------------

create table public.player_states (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  first_name text,
  role text,
  group_id text,
  xp int not null default 0,
  state jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.player_states enable row level security;

create policy "chacun lit son état" on public.player_states
  for select using (auth.uid() = user_id);
create policy "chacun crée son état" on public.player_states
  for insert with check (auth.uid() = user_id);
create policy "chacun met à jour son état" on public.player_states
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Événements d'usage (KPI investisseurs). Écriture seule côté app.
-- ---------------------------------------------------------------------------

create table public.events (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  props jsonb not null default '{}',
  client_time timestamptz,
  created_at timestamptz not null default now()
);

create index events_user_idx on public.events (user_id, created_at);
create index events_name_idx on public.events (name, created_at);

alter table public.events enable row level security;

create policy "chacun écrit ses événements" on public.events
  for insert with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Droits explicites pour l'API (les nouveaux projets Supabase n'exposent pas
-- toujours les tables automatiquement). Les joueurs anonymes ont le rôle
-- « authenticated ».
-- ---------------------------------------------------------------------------

grant usage on schema public to anon, authenticated;
grant select on public.cultural_groups, public.categories, public.levels, public.activities, public.challenges
  to anon, authenticated;
grant select, insert, update on public.player_states to authenticated;
grant insert on public.events to authenticated;

-- ---------------------------------------------------------------------------
-- Vues KPI (à consulter dans le SQL Editor ; non exposées à l'app).
-- ---------------------------------------------------------------------------

create schema if not exists kpi;
revoke all on schema kpi from anon, authenticated;

-- Résumé global : inscrits, activation, complétion, rétention J+7.
create or replace view kpi.summary as
with users as (
  select user_id, min(coalesce(client_time, created_at)) as first_seen
  from public.events group by user_id
),
per_user as (
  select
    u.user_id,
    u.first_seen,
    bool_or(e.name = 'onboarding_completed') as onboarded,
    bool_or(e.name = 'level_started') as activated,
    bool_or(e.name = 'level_completed' and (e.props->>'passed')::boolean) as passed_level,
    bool_or(e.name = 'challenge_completed') as did_challenge,
    bool_or(coalesce(e.client_time, e.created_at) >= u.first_seen + interval '7 days') as returned_d7
  from users u join public.events e using (user_id)
  group by u.user_id, u.first_seen
)
select
  count(*) as joueurs,
  round(100.0 * count(*) filter (where activated) / nullif(count(*), 0), 1) as activation_pct,
  round(100.0 * count(*) filter (where passed_level) / nullif(count(*) filter (where activated), 0), 1) as niveau_valide_pct,
  round(100.0 * count(*) filter (where did_challenge) / nullif(count(*), 0), 1) as defi_realise_pct,
  round(100.0 * count(*) filter (where returned_d7) / nullif(count(*) filter (where first_seen < now() - interval '7 days'), 0), 1) as retention_j7_pct
from per_user;

-- Taux de réussite par question : repère les questions mal formulées.
create or replace view kpi.questions as
select
  props->>'activity' as activite,
  count(*) as reponses,
  round(100.0 * count(*) filter (where (props->>'correct')::boolean) / count(*), 1) as reussite_pct
from public.events
where name = 'answer'
group by 1
order by reussite_pct;

-- Notes partagées depuis les défis (avec accord du joueur) : matière pour
-- de nouveaux contenus, à faire valider avant usage.
create or replace view kpi.notes_partagees as
select created_at, props->>'challenge' as defi, props->>'note' as note
from public.events
where name = 'challenge_completed' and props ? 'note'
order by created_at desc;
