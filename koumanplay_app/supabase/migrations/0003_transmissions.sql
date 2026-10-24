-- KoumanPlay : transmissions des aînés (mots, proverbes, contes enregistrés
-- à la voix dans l'app). À exécuter APRÈS 0002_langues.sql.

create table public.contributions (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('mot', 'proverbe', 'conte')),
  language_id text not null references public.languages(id),
  prompt_id text,                      -- mot demandé, ex. « 1-04 »
  prompt_french text,                  -- ex. « Merci »
  text text,                           -- traduction d'un proverbe, titre d'un conte
  audio_paths text[] not null,         -- fichiers dans le bucket « contributions »
  contributor_name text,               -- null = l'aîné préfère rester anonyme
  village text,
  consent_at timestamptz,              -- accord donné dans l'app
  -- À remplir par l'équipe après écoute :
  status text not null default 'en_verification'
    check (status in ('en_verification', 'publie', 'refuse')),
  transcription text,                  -- le mot / proverbe écrit dans la langue
  team_note text,
  created_at timestamptz not null default now()
);

create index contributions_status_idx on public.contributions (status, created_at);

alter table public.contributions enable row level security;

-- L'aîné envoie ses transmissions et suit leur statut ; seule l'équipe
-- (dashboard Supabase) change le statut.
create policy "chacun envoie ses transmissions" on public.contributions
  for insert with check (auth.uid() = user_id);
create policy "chacun renvoie ses transmissions" on public.contributions
  for update using (auth.uid() = user_id and status = 'en_verification')
  with check (auth.uid() = user_id and status = 'en_verification');
create policy "chacun voit ses transmissions" on public.contributions
  for select using (auth.uid() = user_id);

grant select, insert, update on public.contributions to authenticated;

-- Enregistrements audio : bucket privé, un dossier par joueur.
insert into storage.buckets (id, name, public)
values ('contributions', 'contributions', false)
on conflict (id) do nothing;

create policy "chacun dépose ses enregistrements" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'contributions' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "chacun remplace ses enregistrements" on storage.objects
  for update to authenticated
  using (bucket_id = 'contributions' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "chacun écoute ses enregistrements" on storage.objects
  for select to authenticated
  using (bucket_id = 'contributions' and (storage.foldername(name))[1] = auth.uid()::text);

-- Pour l'équipe : ce qui attend d'être écouté, et le total par langue.
create or replace view kpi.transmissions as
select
  language_id as langue,
  count(*) as total,
  count(*) filter (where kind = 'mot') as mots,
  count(*) filter (where kind = 'proverbe') as proverbes,
  count(*) filter (where kind = 'conte') as contes,
  count(*) filter (where status = 'en_verification') as a_verifier,
  count(*) filter (where status = 'publie') as publies,
  count(distinct user_id) as aines
from public.contributions
group by language_id
order by total desc;
