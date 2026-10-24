-- KoumanPlay : carte des langues (étapes) avec niveaux mots → phrases → proverbes.
-- À exécuter APRÈS 0001_init.sql, puis relancer supabase/seed.sql.

create table public.languages (
  id text primary key,
  name text not null,
  "group" text not null default '',
  region text not null default '',
  color text not null default '#5B2EFF',
  sort int not null default 0
);

-- Les niveaux appartiennent maintenant à une langue.
alter table public.levels alter column category_id drop not null;
alter table public.levels add column language_id text references public.languages(id);
alter table public.levels add column kind text not null default 'mots'
  check (kind in ('mots', 'phrases', 'proverbes'));

-- Mots et phrases : les questions sont générées par l'app (4 choix).
-- Remplissable directement dans le Table Editor, ou par import CSV.
create table public.words (
  id text primary key,
  level_id text not null references public.levels(id),
  french text not null,
  local text not null,                 -- dans la langue locale
  pronunciation text,                  -- aide à la lecture, ex. « a-kwa-ba »
  audio text,                          -- URL Supabase Storage de l'enregistrement
  xp int not null default 10,
  validated boolean not null default false,
  validated_by text,
  published boolean not null default true,
  sort int not null default 0
);

alter table public.activities add column audio text;

alter table public.languages enable row level security;
alter table public.words enable row level security;

create policy "lecture publique" on public.languages for select using (true);
create policy "lecture publique" on public.words for select using (published);

grant select on public.languages, public.words to anon, authenticated;

-- Taux de réussite par langue.
create or replace view kpi.langues as
select
  split_part(props->>'level', '-', 1) as langue,
  count(*) filter (where name = 'level_started') as parties,
  count(*) filter (where name = 'level_completed' and (props->>'passed')::boolean) as niveaux_valides
from public.events
where name in ('level_started', 'level_completed')
group by 1
order by parties desc;
