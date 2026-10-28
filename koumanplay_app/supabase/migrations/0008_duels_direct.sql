-- Duels en direct (Tir à la corde, Paires express) et encouragements des
-- aînés dans chaque langue (v1.8).
-- À lancer dans l'éditeur SQL de Supabase. Relançable sans risque.
--
-- Les parties se jouent en temps réel par Supabase Realtime (canal
-- « duel:<id> ») ; ces tables servent seulement à mettre deux joueurs en
-- relation. Les joueurs n'y accèdent que par les fonctions ci-dessous.

-- ---------------------------------------------------------------- Encouragements

-- « Bravo », « encore », « tu as gagné » enregistrés par un aîné, joués après
-- le son d'une bonne réponse (kind = correct), d'une erreur (wrong) ou d'une
-- victoire (win). À remplir avec les enregistrements validés par le référent.
create table if not exists public.language_sounds (
  id bigint generated always as identity primary key,
  language_id text not null,
  kind text not null check (kind in ('correct', 'wrong', 'win')),
  audio text not null,                          -- URL Supabase Storage
  text text,                                    -- ce qui est dit, et sa traduction
  published boolean not null default false
);

alter table public.language_sounds enable row level security;
drop policy if exists "encouragements publiés lisibles" on public.language_sounds;
create policy "encouragements publiés lisibles" on public.language_sounds
  for select using (published);

-- ---------------------------------------------------------------- Parties

create table if not exists public.live_matches (
  id uuid primary key default gen_random_uuid(),
  mode text not null check (mode in ('corde', 'paires')),
  language_id text not null,
  seed integer not null,
  code text unique,                             -- défi entre amis
  player_a uuid not null references auth.users (id) on delete cascade,
  a_name text not null default '',
  a_avatar jsonb,
  player_b uuid references auth.users (id) on delete set null,
  b_name text,
  b_avatar jsonb,
  a_score integer,
  a_won boolean,
  b_score integer,
  b_won boolean,
  created_at timestamptz not null default now()
);

create index if not exists live_matches_a on public.live_matches (player_a, created_at desc);
create index if not exists live_matches_b on public.live_matches (player_b, created_at desc);

alter table public.live_matches enable row level security;
drop policy if exists "parties lisibles par leurs joueurs" on public.live_matches;
create policy "parties lisibles par leurs joueurs" on public.live_matches
  for select to authenticated
  using (auth.uid() = player_a or auth.uid() = player_b);

-- File d'attente des joueurs qui cherchent un adversaire inconnu.
create table if not exists public.match_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  mode text not null,
  language_id text not null,
  name text not null default '',
  avatar jsonb,
  match_id uuid references public.live_matches (id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.match_queue enable row level security;

-- Cherche un adversaire pour [p_mode]. Renvoie la partie dès qu'un joueur est
-- trouvé, sinon null : le joueur reste en file et rappelle la fonction.
create or replace function public.match_find(p_mode text, p_language text, p_name text, p_avatar jsonb)
returns public.live_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  mine public.match_queue;
  other public.match_queue;
  m public.live_matches;
begin
  if uid is null then
    raise exception 'non connecté';
  end if;

  -- Un autre joueur m'a déjà pris comme adversaire.
  select * into mine from public.match_queue where user_id = uid;
  if mine.match_id is not null then
    delete from public.match_queue where user_id = uid;
    select * into m from public.live_matches where id = mine.match_id;
    return m;
  end if;

  perform pg_advisory_xact_lock(hashtext('match:' || p_mode));
  select * into other from public.match_queue
    where mode = p_mode and match_id is null and user_id <> uid
      and updated_at > now() - interval '12 seconds'
    order by updated_at
    limit 1;

  if other.user_id is not null then
    -- La partie se joue dans la langue de celui qui attendait.
    insert into public.live_matches (mode, language_id, seed, player_a, a_name, a_avatar, player_b, b_name, b_avatar)
    values (p_mode, other.language_id, floor(random() * 1000000000)::int,
            other.user_id, other.name, other.avatar, uid, left(coalesce(p_name, ''), 30), p_avatar)
    returning * into m;
    update public.match_queue set match_id = m.id where user_id = other.user_id;
    delete from public.match_queue where user_id = uid;
    return m;
  end if;

  insert into public.match_queue (user_id, mode, language_id, name, avatar, match_id, updated_at)
  values (uid, p_mode, p_language, left(coalesce(p_name, ''), 30), p_avatar, null, now())
  on conflict (user_id) do update set
    mode = excluded.mode, language_id = excluded.language_id, name = excluded.name,
    avatar = excluded.avatar, match_id = null, updated_at = now();
  return null;
end;
$$;

-- Quitte la file d'attente.
create or replace function public.match_leave()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.match_queue where user_id = auth.uid() and match_id is null;
$$;

-- Défi entre amis : crée une partie avec un code à 6 caractères.
create or replace function public.room_create(p_mode text, p_language text, p_name text, p_avatar jsonb)
returns public.live_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  new_code text;
  m public.live_matches;
begin
  if auth.uid() is null then
    raise exception 'non connecté';
  end if;
  loop
    new_code := '';
    for i in 1..6 loop
      new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    begin
      insert into public.live_matches (mode, language_id, seed, code, player_a, a_name, a_avatar)
      values (p_mode, p_language, floor(random() * 1000000000)::int, new_code, auth.uid(),
              left(coalesce(p_name, ''), 30), p_avatar)
      returning * into m;
      return m;
    exception when unique_violation then
      -- Code déjà pris : on en tire un autre.
    end;
  end loop;
end;
$$;

-- Rejoint la partie d'un ami avec son code (valable 30 minutes).
create or replace function public.room_join(p_code text, p_name text, p_avatar jsonb)
returns public.live_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  m public.live_matches;
begin
  if auth.uid() is null then
    raise exception 'non connecté';
  end if;
  select * into m from public.live_matches where code = upper(trim(p_code)) for update;
  if m.id is null then
    raise exception 'duel introuvable';
  end if;
  if m.player_a = auth.uid() then
    raise exception 'ton propre duel';
  end if;
  if m.player_b is not null and m.player_b <> auth.uid() then
    raise exception 'duel déjà pris';
  end if;
  if m.created_at < now() - interval '30 minutes' then
    raise exception 'duel expiré';
  end if;
  update public.live_matches set player_b = auth.uid(), b_name = left(coalesce(p_name, ''), 30), b_avatar = p_avatar
  where id = m.id
  returning * into m;
  return m;
end;
$$;

-- Fin de partie : le score et le résultat vus par ce joueur.
create or replace function public.match_finish(p_id uuid, p_score integer, p_won boolean)
returns void
language sql
security definer
set search_path = public
as $$
  update public.live_matches set
    a_score = case when player_a = auth.uid() and a_score is null then p_score else a_score end,
    a_won = case when player_a = auth.uid() and a_score is null then p_won else a_won end,
    b_score = case when player_b = auth.uid() and b_score is null then p_score else b_score end,
    b_won = case when player_b = auth.uid() and b_score is null then p_won else b_won end
  where id = p_id and (player_a = auth.uid() or player_b = auth.uid());
$$;

grant execute on function public.match_find(text, text, text, jsonb) to authenticated;
grant execute on function public.match_leave() to authenticated;
grant execute on function public.room_create(text, text, text, jsonb) to authenticated;
grant execute on function public.room_join(text, text, jsonb) to authenticated;
grant execute on function public.match_finish(uuid, integer, boolean) to authenticated;
