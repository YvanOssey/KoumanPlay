-- Bibliothèque des œuvres culturelles, événements des structures partenaires
-- et réglages de l'app (seuils pour participer aux événements).
-- À lancer dans l'éditeur SQL de Supabase, après 0003_transmissions.sql.
-- Relançable sans risque.
--
-- Les événements culturels sont dans culture_events : la table « events »
-- existe déjà (statistiques d'usage, 0001_init.sql).
--
-- Ajouter une œuvre ou un événement : Table Editor > works ou culture_events >
-- Insert row, puis cocher « published » quand la fiche est vérifiée.

create table if not exists public.works (
  id text primary key,
  title text not null,
  kind text not null default 'Œuvre',      -- Masque, Statue, Textile, Instrument…
  description text not null default '',
  people text,                              -- peuple ou groupe d'origine
  region text,
  period text,
  museum text,                              -- où la voir
  city text,
  address text,
  image_url text,                           -- image dont on a les droits
  link text,                                -- page du musée ou de l'œuvre
  source text,                              -- d'où viennent les informations (interne)
  published boolean not null default false,
  sort integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.culture_events (
  id text primary key,
  title text not null,
  organizer text not null default '',       -- structure partenaire
  description text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz,
  place text,
  city text,
  image_url text,
  link text,                                -- page de l'événement ou de la structure
  min_diamonds integer,                     -- vide = seuil général (app_settings)
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  note text
);

insert into public.app_settings (key, value, note) values
  ('eventMinDiamonds', '3', 'Diamants pour participer à un événement (1 diamant par niveau validé).'),
  ('eventMinLevel', '2', 'Niveau de joueur minimum (200 XP par niveau).')
on conflict (key) do nothing;

alter table public.works enable row level security;
alter table public.culture_events enable row level security;
alter table public.app_settings enable row level security;

drop policy if exists "lecture publique" on public.works;
drop policy if exists "lecture publique" on public.culture_events;
drop policy if exists "lecture publique" on public.app_settings;
create policy "lecture publique" on public.works for select using (published);
create policy "lecture publique" on public.culture_events for select using (published);
create policy "lecture publique" on public.app_settings for select using (true);

grant select on public.works, public.culture_events, public.app_settings to anon, authenticated;
